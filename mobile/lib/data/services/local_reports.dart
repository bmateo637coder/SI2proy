import 'dart:convert';

class LocalReports {
  static DateTime? day(Object? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse('$value');
    if (parsed == null || parsed.toIso8601String().split('T').first != '$value')
      throw StateError('Usa una fecha válida con formato YYYY-MM-DD.');
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static const columns = {
    'propiedades': [
      'id_propiedad',
      'titulo',
      'direccion',
      'precio',
      'tipo_operacion',
      'estado',
    ],
    'clientes': ['ci', 'nombre', 'correo', 'telefono'],
    'usuarios': ['ci', 'nombre', 'correo', 'telefono', 'id_rol'],
  };
  static List<Map<String, dynamic>> rows(
    Map<String, dynamic> data,
    String name,
  ) => (data[name] as List? ?? [])
      .map((r) => Map<String, dynamic>.from(r))
      .toList();
  static Map<String, dynamic> dynamicReport(
    Map<String, dynamic> data,
    Map<String, dynamic> spec,
    bool all,
  ) {
    final entity = spec['entidad'] as String? ?? '';
    final selected = List<String>.from(spec['columnas'] ?? []);
    final allowed = columns[entity];
    if (allowed == null ||
        selected.isEmpty ||
        selected.any((c) => !allowed.contains(c)))
      throw StateError('Selecciona columnas válidas para el reporte.');
    var result = rows(data, entity);
    for (final filter in spec['filtros'] as List? ?? []) {
      final c = filter['columna'].toString(),
          op = filter['operador'].toString();
      if (!allowed.contains(c) ||
          !['eq', 'gt', 'lt', 'gte', 'lte', 'like'].contains(op))
        throw StateError('Filtro no permitido.');
      final numeric = ['id_propiedad', 'precio', 'id_rol'].contains(c);
      final value = numeric
          ? num.tryParse('${filter['valor']}')
          : filter['valor'].toString();
      if (numeric && (value == null || op == 'like'))
        throw StateError(
          'El filtro $c necesita un número y un operador numérico.',
        );
      result = result.where((row) {
        final actual = numeric
            ? num.tryParse('${row[c]}') ?? 0
            : row[c]?.toString() ?? '';
        if (op == 'like')
          return actual.toString().toLowerCase().contains(
            value.toString().toLowerCase(),
          );
        final compare = numeric
            ? (actual as num).compareTo(value as num)
            : actual.toString().compareTo(value.toString());
        return switch (op) {
          'eq' => compare == 0,
          'gt' => compare > 0,
          'gte' => compare >= 0,
          'lt' => compare < 0,
          'lte' => compare <= 0,
          _ => false,
        };
      }).toList();
    }
    final order = spec['orden'];
    if (order is Map && allowed.contains(order['columna'])) {
      final field = order['columna'];
      result.sort((a, b) {
        final x = a[field], y = b[field];
        final n = x is num && y is num ? x.compareTo(y) : '$x'.compareTo('$y');
        return order['direccion'] == 'desc' ? -n : n;
      });
    }
    final limit = ((spec['limite'] as num?)?.toInt() ?? 500).clamp(1, 1000);
    final fields = [if (all) 'inmobiliaria', ...selected];
    return {
      'columnas': fields,
      'data': result
          .take(limit)
          .map((r) => {for (final c in fields) c: r[c]})
          .toList(),
      'truncado': result.length > limit,
      'origen': 'local',
      'limite': limit,
    };
  }

  static Map<String, dynamic> conventional(
    Map<String, dynamic> data,
    Map<String, dynamic> spec,
    bool all,
  ) {
    final kind = spec['tipo']?.toString() ?? 'cartera_estado';
    if (![
      'cartera_estado',
      'reservas_sucursal',
      'ventas_sucursal',
      'ranking_agentes',
      'ingresos_semana',
    ].contains(kind))
      throw StateError('Tipo de reporte no soportado.');
    final from = day(spec['desde']), to = day(spec['hasta']);
    final limit = (spec['limite'] as num?)?.toInt() ?? 100;
    if (limit < 1 || limit > 500)
      throw StateError('El límite debe estar entre 1 y 500.');
    if (kind != 'cartera_estado' && spec['estado'] != null)
      throw StateError('El estado de cartera no se aplica a este reporte.');
    if (kind == 'reservas_sucursal' && spec['tipo_contrato'] != null)
      throw StateError(
        'Para reservas usa fecha y sucursal; el tipo de contrato no se aplica.',
      );
    if (spec['id_sucursal'] != null &&
        !rows(
          data,
          'sucursales',
        ).any((b) => b['id_sucursal'] == spec['id_sucursal']))
      throw StateError('La sucursal no está disponible en esta selección.');
    if (from != null && to != null && from.isAfter(to))
      throw StateError('Rango de fechas invertido.');
    if (kind == 'cartera_estado' && (from != null || to != null))
      throw StateError(
        'La cartera muestra el estado actual de la copia local; no tiene historial por fecha.',
      );
    final props = rows(data, 'propiedades');
    final propById = {for (final p in props) p['id_propiedad']: p};
    final branches = {
      for (final b in rows(data, 'sucursales')) b['id_sucursal']: b['nombre'],
    };
    bool inRange(String? stamp) {
      final d = DateTime.tryParse(stamp ?? '');
      if (d == null) return false;
      final day = DateTime(d.year, d.month, d.day);
      return (from == null || !day.isBefore(from)) &&
          (to == null || !day.isAfter(to));
    }

    bool branchMatches(Map p) =>
        spec['id_sucursal'] == null || p['id_sucursal'] == spec['id_sucursal'];
    final groups = <String, List<dynamic>>{};
    void add(List<dynamic> labels, num value, {bool countOnly = false}) {
      final key = jsonEncode(labels);
      final row = groups.putIfAbsent(
        key,
        () => [...labels, 0, if (!countOnly) 0.0],
      );
      row[labels.length] = (row[labels.length] as num) + 1;
      if (!countOnly)
        row[labels.length + 1] = (row[labels.length + 1] as num) + value;
    }

    List<String> cols;
    String title;
    if (kind == 'cartera_estado') {
      for (final p in props.where(branchMatches)) {
        if (spec['estado'] != null && p['estado'] != spec['estado']) continue;
        if (spec['tipo_contrato'] != null &&
            p['tipo_operacion'] != spec['tipo_contrato'])
          continue;
        add([
          if (all) p['inmobiliaria'],
          p['estado'],
        ], num.tryParse('${p['precio']}') ?? 0);
      }
      cols = ['Estado', 'Propiedades', 'Valor de cartera'];
      title = 'Cartera actual por estado';
    } else if (kind == 'reservas_sucursal') {
      for (final op in rows(data, 'reservas')) {
        if (op['tipo'] != 'reserva' ||
            !['confirmada', 'pendiente'].contains(op['estado']) ||
            !inRange(op['registrado_en']?.toString()))
          continue;
        final p = propById[op['id_propiedad']] ?? {};
        if (branchMatches(p)) {
          final labels = [
            if (all) p['inmobiliaria'],
            branches[op['id_sucursal']] ?? 'Sucursal ${op['id_sucursal']}',
          ];
          final row = groups.putIfAbsent(
            jsonEncode(labels),
            () => [...labels, 0, 0],
          );
          final index = labels.length + (op['estado'] == 'pendiente' ? 1 : 0);
          row[index] = (row[index] as num) + 1;
        }
      }
      cols = ['Sucursal', 'Reservas confirmadas', 'Pendientes locales'];
      title = 'Reservas por sucursal';
    } else {
      for (final c in rows(data, 'contratos')) {
        final p = propById[c['id_propiedad']] ?? {};
        if (!branchMatches(p) ||
            (spec['tipo_contrato'] != null &&
                c['tipo_contrato'] != spec['tipo_contrato']))
          continue;
        if (kind == 'ingresos_semana') {
          for (final pay in c['pagos'] as List? ?? []) {
            if (!inRange(pay['fecha_pago']?.toString())) continue;
            final d = DateTime.parse(pay['fecha_pago']);
            final monday = DateTime(d.year, d.month, d.day)
                .subtract(Duration(days: d.weekday - 1))
                .toIso8601String()
                .split('T')
                .first;
            add([
              if (all) c['inmobiliaria'],
              monday,
            ], num.tryParse('${pay['monto']}') ?? 0);
          }
        } else if (inRange(c['fecha_inicio']?.toString())) {
          add([
            if (all) c['inmobiliaria'],
            kind == 'ranking_agentes'
                ? c['agente'] ?? 'Sin agente'
                : branches[p['id_sucursal']] ?? 'Sin sucursal',
          ], num.tryParse('${c['monto_total']}') ?? 0);
        }
      }
      cols = kind == 'ingresos_semana'
          ? ['Semana desde', 'Ingresos cobrados']
          : [
              kind == 'ranking_agentes' ? 'Agente' : 'Sucursal',
              'Contratos',
              'Monto contratado',
            ];
      title = kind == 'ingresos_semana'
          ? 'Ingresos por semana'
          : kind == 'ranking_agentes'
          ? 'Ranking de agentes'
          : 'Contratos por sucursal';
    }
    var result = groups.values.toList();
    if (kind == 'ingresos_semana')
      result = result.map((r) => [...r.take(r.length - 2), r.last]).toList();
    if (kind == 'ranking_agentes')
      result.sort((a, b) => (b.last as num).compareTo(a.last as num));
    final truncated = result.length > limit;
    result = result
        .take(limit)
        .map(
          (r) =>
              r.map((v) => v is double ? (v * 100).round() / 100 : v).toList(),
        )
        .toList();
    return {
      'titulo': title,
      'columnas': [if (all) 'Inmobiliaria', ...cols],
      'filas': result,
      'interprete': 'calculo_local',
      'origen': 'local',
      'truncado': truncated,
      'resumen': 'Calculado en el teléfono con la copia local y los cambios pendientes.',
      'filtros': spec,
    };
  }

  static Map<String, dynamic> naturalSpec(String text) {
    var t = text.toLowerCase();
    for (final pair in {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ñ': 'n',
    }.entries) {
      t = t.replaceAll(pair.key, pair.value);
    }
    final type = t.contains('reserva')
        ? 'reservas_sucursal'
        : t.contains('agente')
        ? 'ranking_agentes'
        : RegExp('ingreso|semana|cobro|pago').hasMatch(t)
        ? 'ingresos_semana'
        : RegExp('cartera|propiedad|inmueble|disponib|estado').hasMatch(t)
        ? 'cartera_estado'
        : RegExp('venta|contrato|alquiler|anticretico').hasMatch(t)
        ? 'ventas_sucursal'
        : null;
    if (type == null)
      throw StateError(
        'Sin conexión puedes pedir cartera por estado, ventas por sucursal, ingresos semanales, ranking de agentes o reservas.',
      );
    final dates = RegExp(r'\d{4}-\d{2}-\d{2}')
        .allMatches(t)
        .map((m) => m[0]!)
        .toList();
    final spec = <String, dynamic>{'tipo': type};
    final bolivia = DateTime.now().toUtc().subtract(const Duration(hours: 4));
    final today = DateTime(bolivia.year, bolivia.month, bolivia.day);
    String iso(DateTime d) => d.toIso8601String().split('T').first;
    if (dates.isNotEmpty) {
      spec['desde'] = iso(day(dates.first)!);
      spec['hasta'] = iso(day(dates.last)!);
    } else if (t.contains('este mes')) {
      spec['desde'] = iso(DateTime(today.year, today.month, 1));
      spec['hasta'] = iso(today);
    } else if (t.contains('este ano')) {
      spec['desde'] = iso(DateTime(today.year, 1, 1));
      spec['hasta'] = iso(today);
    } else if (t.contains('ultimos tres meses') ||
        t.contains('ultimo trimestre')) {
      spec['desde'] = iso(today.subtract(const Duration(days: 90)));
      spec['hasta'] = iso(today);
    } else {
      const months = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ];
      final found = months.indexed
          .where((e) => t.contains(e.$2))
          .map((e) => e.$1 + 1)
          .toList();
      if (found.length > 1)
        throw StateError(
          'Para varios meses indica un rango YYYY-MM-DD a YYYY-MM-DD.',
        );
      if (found.isNotEmpty) {
        final year =
            int.tryParse(RegExp(r'\b20\d{2}\b').firstMatch(t)?[0] ?? '') ??
            today.year;
        spec['desde'] = iso(DateTime(year, found.single, 1));
        spec['hasta'] = iso(DateTime(year, found.single + 1, 0));
      }
    }
    final branch = RegExp(r'sucursal\s*(?:#|id\s*)?(\d+)').firstMatch(t);
    if (branch != null) {
      spec['id_sucursal'] = int.parse(branch[1]!);
    } else if (RegExp(r'sucursal\s+(?!durante|este|del|de\b|en\b|por\b)[a-z]+')
        .hasMatch(t))
      throw StateError(
        'Indica el número de sucursal, por ejemplo: sucursal 1.',
      );
    for (final pair in {
      'alquiler': 'Alquiler',
      'anticretico': 'Anticretico',
      'venta': 'Venta',
    }.entries) {
      if (t.contains(pair.key)) {
        spec['tipo_contrato'] = pair.value;
        break;
      }
    }
    for (final pair in {
      'disponib': 'Disponible',
      'vendida': 'Vendida',
      'alquilada': 'Alquilada',
      'reservada': 'Reservada',
    }.entries) {
      if (t.contains(pair.key)) {
        spec['estado'] = pair.value;
        break;
      }
    }
    final top = RegExp(r'(?:top|primeros|mejores)\s*(\d+)').firstMatch(t);
    if (top != null) spec['limite'] = int.parse(top[1]!);
    return spec;
  }
}
