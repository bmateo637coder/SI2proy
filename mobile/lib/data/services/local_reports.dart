import 'dart:convert';

class LocalReports {
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
    final from = DateTime.tryParse(spec['desde']?.toString() ?? ''),
        to = DateTime.tryParse(spec['hasta']?.toString() ?? '');
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
    return {
      'titulo': title,
      'columnas': [if (all) 'Inmobiliaria', ...cols],
      'filas': result,
      'interprete': 'calculo_local',
      'origen': 'local',
      'resumen': 'Calculado en el teléfono con la copia local y los cambios pendientes.',
      'filtros': spec,
    };
  }

  static Map<String, dynamic> naturalSpec(String text) {
    final t = text.toLowerCase();
    final type = t.contains('reserva')
        ? 'reservas_sucursal'
        : t.contains('agente')
        ? 'ranking_agentes'
        : RegExp('ingreso|semana|cobro|pago').hasMatch(t)
        ? 'ingresos_semana'
        : RegExp('cartera|propiedad|inmueble|disponib|estado').hasMatch(t)
        ? 'cartera_estado'
        : RegExp('venta|contrato|alquiler').hasMatch(t)
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
    return {
      'tipo': type,
      if (dates.isNotEmpty) 'desde': dates.first,
      if (dates.isNotEmpty) 'hasta': dates.last,
    };
  }
}
