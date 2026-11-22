import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../data/services/sprint4_service.dart';
import '../../data/services/push_service.dart';
import '../providers/auth_provider.dart';

class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key});
  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen> {
  String section = 'Inicio',
      message = '',
      metric = 'cierres',
      answer = '',
      mode = '';
  bool loading = false;
  dynamic data;
  List<dynamic> properties = [];
  int? propertyId;
  final text = TextEditingController();
  final question = TextEditingController();
  Sprint4Service get service => context.read<Sprint4Service>();
  bool get staff => service.staff;
  Future<void> act(Future<void> Function() work) async {
    if (loading) return;
    setState(() {
      loading = true;
      message = '';
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        final detail = e is DioException
            ? (e.response?.data is Map ? e.response?.data['detail'] : null)
            : null;
        message = detail is String
            ? detail
            : e is StateError
            ? '${e.message}'
            : 'No se pudo completar la operación. Revisa la conexión y vuelve a intentar.';
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> open(String name) async {
    setState(() {
      section = name;
      data = null;
      answer = '';
    });
    await act(() async {
      final paths = <String, String>{
        'Favoritos': '/api/favoritos',
        'Alertas': '/api/alertas',
        'Recomendaciones': '/api/recomendaciones',
        'Mi cuenta': '/api/mi-cuenta',
        'Mantenimiento': '/api/mantenimiento',
        'Gerencia': '/api/gerencia/dashboard',
        'Mapa de ventas': '/api/analitica/zonas',
        'Comisiones': '/api/comisiones',
        'Promociones': '/api/promociones',
        'Notificaciones': '/api/bandeja',
        'Plan y suscripción': '/api/saas/planes',
        'Reporte ejecutivo': '/api/reportes/ejecutivo',
      };
      if (paths.containsKey(name))
        data = await service.get(
          paths[name]!,
          params: name == 'Mapa de ventas' ? {'metrica': metric} : null,
        );
      if ([
        'Búsqueda',
        'Asistente e IA',
        'Promociones',
        'Mantenimiento',
      ].contains(name)) {
        properties = List.from(
          await service.get(
            name == 'Mantenimiento'
                ? '/api/mantenimiento/mis-inmuebles'
                : '/modulo_inmuebles/propiedades/catalogo',
          ),
        );
        if (!properties.any((p) => p['id_propiedad'] == propertyId))
          propertyId = null;
      }
      if (name == 'Sincronización de servicios') data = await service.changes();
    });
  }

  Future<Map<String, String>?> form(
    String title,
    Map<String, String> fields, {
    Map<String, String> initial = const {},
  }) async {
    final controllers = {
      for (final key in fields.keys)
        key: TextEditingController(text: initial[key] ?? ''),
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[field.key],
                    decoration: InputDecoration(labelText: field.value),
                    maxLines:
                        field.key == 'descripcion' || field.key == 'comentario'
                        ? 3
                        : 1,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, {
              for (final e in controllers.entries) e.key: e.value.text.trim(),
            }),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    // Los controladores se liberan después de que termine la animación del diálogo.
    Future.delayed(const Duration(milliseconds: 400), () {
      for (final c in controllers.values) c.dispose();
    });
    return result;
  }

  Future<void> mutate(
    String method,
    String path, [
    Map<String, dynamic> body = const {},
    int? version,
  ]) async {
    final detailId = section == 'Detalle de mantenimiento' && data is Map
        ? data['id'] as int?
        : null;
    await act(() async {
      final result = await service.mutate(method, path, body, version);
      message = result['pendiente'] == true
          ? 'Guardado en el teléfono. Pendiente de sincronización.'
          : 'Cambio confirmado por el servidor.';
    });
    if (mounted && !service.offline) {
      final notice = message;
      if (detailId != null) {
        await maintenanceDetail(detailId);
      } else {
        await open(section);
      }
      if (mounted) setState(() => message = notice);
    }
  }

  Widget button(String label, VoidCallback onTap, {IconData? icon}) => Padding(
    padding: const EdgeInsets.all(4),
    child: FilledButton.tonalIcon(
      onPressed: loading ? null : onTap,
      icon: Icon(icon ?? Icons.chevron_right),
      label: Text(label),
    ),
  );
  Widget card(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
  Widget pickProperty() => DropdownButtonFormField<int>(
    initialValue: propertyId,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Inmueble'),
    items: [
      for (final p in properties)
        DropdownMenuItem(
          value: p['id_propiedad'] as int,
          child: Text('${p['titulo']}', overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) => setState(() => propertyId = v),
  );
  Widget propertyCard(
    Map p, {
    bool favorite = false,
    List<dynamic> reasons = const [],
  }) => card('${p['titulo']}', [
    Text('${p['direccion'] ?? ''} · ${p['tipo_operacion'] ?? ''}'),
    Text('Precio: ${p['precio']}'),
    if (reasons.isNotEmpty) Text(reasons.join(' · ')),
    Wrap(
      children: [
        button(
          favorite ? 'Quitar favorito' : 'Guardar favorito',
          () => mutate(
            favorite ? 'DELETE' : 'POST',
            '/api/favoritos/${p['id_propiedad']}',
          ),
          icon: favorite ? Icons.heart_broken : Icons.favorite_outline,
        ),
        button('Usar en IA', () {
          setState(() => propertyId = p['id_propiedad'] as int);
          open('Asistente e IA');
        }),
      ],
    ),
  ]);
  Future<void> search() async {
    await act(() async {
      data = await service.search(text.text);
    });
  }

  Future<void> ai(String action) async {
    await act(() async {
      if (action != 'chat' && propertyId == null)
        throw StateError('Selecciona un inmueble.');
      final r = await service.ai(action, propertyId, question.text);
      answer = r['respuesta'].toString();
      mode = '${r['modo']} ${r['advertencia'] ?? ''}';
    });
  }

  Future<void> createAlert() async {
    final value = await form('Nueva alerta', {
      'nombre': 'Nombre',
      'texto': 'Qué inmueble buscas',
    });
    if (value == null) return;
    await mutate('POST', '/api/alertas', value);
  }

  Future<void> createMaintenance() async {
    if (propertyId == null) {
      setState(() => message = 'Selecciona el inmueble antes de registrar.');
      return;
    }
    final value = await form('Registrar incidencia', {
      'titulo': 'Título',
      'descripcion': 'Describe el problema',
    });
    if (value == null) return;
    await mutate('POST', '/api/mantenimiento', {
      'id_propiedad': propertyId,
      ...value,
    });
  }

  Future<void> maintenanceDetail(int id) async {
    await act(() async {
      data = await service.get('/api/mantenimiento/$id');
      section = 'Detalle de mantenimiento';
    });
  }

  Future<void> uploadPhoto(Map row) async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted)
        setState(() => message = 'La imagen debe pesar menos de 5 MB.');
      return;
    }
    await mutate('POST', '/api/mantenimiento/${row['id']}/fotos', {
      'contenido': base64Encode(bytes),
    });
    if (mounted && !service.offline) await maintenanceDetail(row['id'] as int);
  }

  Future<void> addCost(Map row) async {
    final v = await form('Registrar costo', {
      'concepto': 'Concepto',
      'monto': 'Monto',
    });
    if (v == null) return;
    await mutate('POST', '/api/mantenimiento/${row['id']}/costos', v);
    if (mounted && !service.offline) await maintenanceDetail(row['id'] as int);
  }

  Future<void> promotion() async {
    if (propertyId == null) {
      setState(() => message = 'Selecciona un inmueble.');
      return;
    }
    final v = await form(
      'Nueva promoción',
      {
        'titulo': 'Título',
        'descuento_pct': 'Descuento %',
        'inicio': 'Inicio AAAA-MM-DD',
        'fin': 'Fin AAAA-MM-DD',
      },
      initial: {
        'inicio': DateTime.now().toIso8601String().substring(0, 10),
        'fin': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String()
            .substring(0, 10),
      },
    );
    if (v != null)
      await mutate('POST', '/api/promociones', {
        'id_propiedad': propertyId,
        ...v,
      });
  }

  Future<void> exportExecutive() async {
    await act(() async {
      final report = await service.get('/api/reportes/ejecutivo') as Map;
      final pdf = pw.Document();
      final income = report['ingresos'] as Map;
      pdf.addPage(
        pw.MultiPage(
          build: (_) => [
            pw.Header(level: 0, child: pw.Text('Reporte ejecutivo Raices')),
            pw.Text('Alcance: ${context.read<AuthProvider>().scopeLabel}'),
            pw.Text('Datos de la ultima descarga disponible'),
            pw.SizedBox(height: 20),
            pw.Text('Inmuebles: ${report['cartera']['total']}'),
            for (final e in income.entries.where((e) => e.key != 'por_mes'))
              pw.Text('${e.key}: ${e.value}'),
            pw.Header(level: 1, text: 'Agentes'),
            for (final a in report['rendimiento_agentes'])
              pw.Text(
                '${a['agente']}: ${a['contratos']} contratos, monto ${a['monto_cerrado']}',
              ),
          ],
        ),
      );
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'reporte-ejecutivo.pdf',
      );
    });
  }

  @override
  void dispose() {
    text.dispose();
    question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<Sprint4Service>();
    final menus = <String, IconData>{
      'Búsqueda': Icons.search,
      'Favoritos': Icons.favorite,
      'Alertas': Icons.notifications_active,
      'Recomendaciones': Icons.recommend,
      'Asistente e IA': Icons.auto_awesome,
      'Mi cuenta': Icons.receipt_long,
      'Mantenimiento': Icons.handyman,
      'Notificaciones': Icons.notifications,
      'Sincronización de servicios': Icons.sync,
      if (staff) ...{
        'Gerencia': Icons.dashboard,
        'Mapa de ventas': Icons.map,
        'Comisiones': Icons.payments,
        'Promociones': Icons.discount,
        'Plan y suscripción': Icons.business,
        'Reporte ejecutivo': Icons.picture_as_pdf,
      },
    };
    final children = <Widget>[
      if (loading) const LinearProgressIndicator(),
      if (message.isNotEmpty) card('Estado', [Text(message)]),
      if (sync.offline)
        const Text('Sin conexión: se muestran los últimos datos descargados.'),
      if (sync.pending > 0 || sync.conflicts > 0)
        ListTile(
          leading: const Icon(Icons.sync_problem),
          title: Text(
            '${sync.pending} pendientes · ${sync.conflicts} conflictos',
          ),
          onTap: () => open('Sincronización de servicios'),
        ),
      if (section == 'Inicio')
        ...menus.entries.map(
          (e) => Card(
            child: ListTile(
              leading: Icon(e.value),
              title: Text(e.key),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(e.key),
            ),
          ),
        ),
      if (section == 'Búsqueda') ...[
        TextField(
          controller: text,
          decoration: const InputDecoration(
            labelText: 'Buscar en lenguaje natural',
            hintText: 'Casa en venta con 3 habitaciones hasta 150 mil',
          ),
        ),
        button('Buscar', search, icon: Icons.search),
        if (data is Map) ...[
          Text('${data['resumen'] ?? ''} · ${data['modo'] ?? ''}'),
          for (final p in data['resultados'] ?? []) propertyCard(Map.from(p)),
        ],
      ],
      if (section == 'Favoritos' && data is List) ...[
        if ((data as List).isEmpty) const Text('No tienes favoritos.'),
        for (final f in data)
          propertyCard(Map.from(f['propiedad']), favorite: true),
      ],
      if (section == 'Alertas') ...[
        button('Crear alerta', createAlert, icon: Icons.add),
        if (data is List) ...[
          if ((data as List).isEmpty) const Text('No tienes alertas.'),
          for (final a in data)
            card('${a['nombre']}', [
              Text('${a['resumen']}'),
              SwitchListTile(
                title: const Text('Activa'),
                value: a['activa'] == true,
                onChanged: (v) =>
                    mutate('PUT', '/api/alertas/${a['id']}', {'activa': v}),
              ),
              button(
                'Eliminar',
                () => mutate('DELETE', '/api/alertas/${a['id']}'),
                icon: Icons.delete,
              ),
            ]),
        ],
      ],
      if (section == 'Recomendaciones' && data is Map) ...[
        Text('Basadas en: ${data['basado_en']}'),
        if ((data['recomendaciones'] as List).isEmpty)
          const Text('No hay recomendaciones disponibles en este alcance.'),
        for (final r in data['recomendaciones']) ...[
          propertyCard(
            Map.from(r['propiedad']),
            reasons: List.from(r['motivos'] ?? []),
          ),
          button('Valorar recomendación', () async {
            final v = await form(
              'Feedback',
              {
                'valoracion': 'Puntuación del 1 al 5',
                'comentario': 'Comentario',
              },
              initial: {'valoracion': '5'},
            );
            if (v != null)
              await mutate('POST', '/api/recomendaciones/feedback', {
                'id_propiedad': r['propiedad']['id_propiedad'],
                'valoracion': int.tryParse(v['valoracion'] ?? '') ?? 0,
                'comentario': v['comentario'],
              });
          }, icon: Icons.star),
        ],
      ],
      if (section == 'Asistente e IA') ...[
        pickProperty(),
        const SizedBox(height: 12),
        TextField(
          controller: question,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Consulta al asistente'),
        ),
        Wrap(
          children: [
            button('Consultar', () => ai('chat')),
            button('Cotizar', () => ai('cotizar')),
            button('Generar descripción', () => ai('descripcion')),
          ],
        ),
        if (answer.isNotEmpty)
          card('Respuesta', [SelectableText(answer), Text(mode)]),
      ],
      if (section == 'Mi cuenta' && data is Map) ...[
        card('Estado de cuenta', [
          Text('Pagado: ${data['pagado']} · Saldo: ${data['saldo']}'),
        ]),
        if ((data['contratos'] as List).isEmpty)
          const Text('No hay contratos en este alcance.'),
        for (final c in data['contratos'])
          card('${c['propiedad']} · ${c['tipo_contrato']}', [
            Text('${c['estado']} · Saldo: ${c['saldo_pendiente']}'),
            for (final q in c['cuotas'] ?? [])
              Text(
                'Cuota ${q['numero_cuota']} · ${q['fecha_vencimiento']} · ${q['monto']} · ${q['estado']}',
              ),
            for (final p in c['pagos'])
              ListTile(
                title: Text('Recibo ${p['numero_recibo']} · ${p['monto']}'),
                trailing: IconButton(
                  tooltip: 'Enviar comprobante por Gmail',
                  icon: const Icon(Icons.email),
                  onPressed: () => act(() async {
                    final r = await context.read<Dio>().post(
                      '/api/pagos/${p['id_pago']}/enviar-recibo',
                      options: Options(extra: {'replicaBypass': true}),
                    );
                    message = 'Comprobante enviado a ${r.data['destinatario']}';
                  }),
                ),
              ),
          ]),
      ],
      if (section == 'Mantenimiento') ...[
        pickProperty(),
        button('Registrar incidencia', createMaintenance, icon: Icons.add),
        if (data is List) ...[
          if ((data as List).isEmpty)
            const Text('No hay incidencias en este alcance.'),
          for (final s in data)
            Card(
              child: ListTile(
                title: Text('${s['titulo']}'),
                subtitle: Text(
                  '${s['estado']} · ${s['urgencia']} · ${s['propiedad']}',
                ),
                onTap: () => maintenanceDetail(s['id'] as int),
              ),
            ),
        ],
      ],
      if (section == 'Detalle de mantenimiento' && data is Map) ...[
        card('${data['titulo']}', [
          Text('${data['descripcion']}'),
          Text(
            '${data['estado']} · ${data['categoria']} · ${data['urgencia']}',
          ),
          Text('Responsable: ${data['responsable'] ?? "Por asignar"}'),
          Text('Contratista: ${data['contratista'] ?? ""}'),
          for (final f in data['fotos'] ?? [])
            if ((f['url'] as String).startsWith('data:'))
              Padding(
                padding: const EdgeInsets.all(8),
                child: Image.memory(
                  base64Decode((f['url'] as String).split(',').last),
                  height: 180,
                  errorBuilder: (_, _, _) =>
                      const Text('No se pudo mostrar la foto.'),
                ),
              ),
          button(
            'Adjuntar foto',
            () => uploadPhoto(Map.from(data)),
            icon: Icons.add_photo_alternate,
          ),
          if (staff) ...[
            for (final state
                in <String, List<String>>{
                      'Recibida': ['Asignada', 'Rechazada'],
                      'Asignada': ['En progreso', 'Resuelta', 'Rechazada'],
                      'En progreso': ['Resuelta', 'Asignada'],
                      'Resuelta': ['Cerrada', 'En progreso'],
                    }[data['estado']] ??
                    [])
              button(
                state,
                () => mutate('PUT', '/api/mantenimiento/${data['id']}', {
                  'estado': state,
                }, data['version'] as int?),
              ),
            button('Asignar contratista', () async {
              final v = await form('Contratista', {
                'contratista': 'Nombre o empresa',
              });
              if (v != null)
                await mutate(
                  'PUT',
                  '/api/mantenimiento/${data['id']}',
                  v,
                  data['version'] as int?,
                );
            }),
            button(
              'Agregar costo',
              () => addCost(Map.from(data)),
              icon: Icons.add,
            ),
            Text('Costo total: ${data['costo_total']}'),
            for (final c in data['costos'] ?? [])
              Text('${c['concepto']}: ${c['monto']}'),
          ],
          for (final e in data['eventos'] ?? [])
            ListTile(
              title: Text('${e['estado']}'),
              subtitle: Text('${e['detalle']} · ${e['fecha']}'),
            ),
        ]),
      ],
      if (section == 'Gerencia' && data is Map) ...[
        for (final item in {
          'Inmuebles': data['cartera']['total'],
          'Cobrado': data['ingresos']['cobrado_total'],
          'Por cobrar': data['ingresos']['por_cobrar'],
          'Vencido': data['ingresos']['vencido'],
          'Mantenimiento abierto': data['mantenimiento']['abiertas'],
          'Costo mantenimiento': data['mantenimiento']['costo_total'],
        }.entries)
          card(item.key, [
            Text(
              '${item.value}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ]),
        for (final a in data['rendimiento_agentes'])
          card('${a['agente']}', [
            Text(
              '${a['contratos']} contratos · monto ${a['monto_cerrado']} · comisión ${a['comision_generada']}',
            ),
          ]),
      ],
      if (section == 'Mapa de ventas') ...[
        DropdownButton<String>(
          value: metric,
          items: const [
            DropdownMenuItem(
              value: 'cierres',
              child: Text('Cantidad de ventas'),
            ),
            DropdownMenuItem(value: 'monto', child: Text('Monto vendido')),
            DropdownMenuItem(value: 'precio_m2', child: Text('Precio por m²')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => metric = v);
              open('Mapa de ventas');
            }
          },
        ),
        if (data is Map) ...[
          SalesMap(zones: List.from(data['zonas'])),
          const Text(
            'Solo contratos de venta. Las zonas sin coordenadas aparecen en el ranking.',
          ),
          for (final z in data['zonas'])
            ListTile(
              title: Text('${z['zona']} · ${z['inmobiliaria']}'),
              subtitle: Text('${z['cierres']} ventas · monto ${z['monto']}'),
            ),
        ],
      ],
      if (section == 'Comisiones' && data is Map) ...[
        Text(
          'Pendiente: ${data['pendiente']} · Liquidado: ${data['liquidado']}',
        ),
        for (final c in data['comisiones'])
          card('${c['agente']}', [
            Text('${c['propiedad']} · ${c['monto']} · ${c['estado']}'),
            if (c['estado'] == 'Pendiente' &&
                context.read<AuthProvider>().user!.isAdministrator)
              button(
                'Liquidar',
                () => mutate('POST', '/api/comisiones/${c['id']}/liquidar'),
              ),
          ]),
      ],
      if (section == 'Promociones') ...[
        pickProperty(),
        button('Crear promoción', promotion),
        if (data is List)
          for (final p in data)
            card('${p['titulo']}', [
              Text(
                '${p['propiedad']} · ${p['descuento_pct']}% · precio promocional ${p['precio_promocional']} · ${p['inicio']} a ${p['fin']}',
              ),
              SwitchListTile(
                title: const Text('Activa'),
                value: p['activa'] == true,
                onChanged: (v) =>
                    mutate('PUT', '/api/promociones/${p['id']}', {'activa': v}),
              ),
              button(
                'Eliminar',
                () => mutate('DELETE', '/api/promociones/${p['id']}'),
              ),
            ]),
      ],
      if (section == 'Plan y suscripción' && data is List) ...[
        const Text(
          'Selecciona una inmobiliaria concreta para cambiar su suscripción.',
        ),
        for (final p in data)
          card('${p['nombre']}', [
            Text(
              'Sucursales: ${p['max_sucursales']} · IA: ${p['reportes_ia'] == true ? "Incluida" : "No incluida"}',
            ),
            if (context.read<AuthProvider>().canWrite)
              button('Aplicar este plan', () async {
                final v = await form(
                  'Vigencia de suscripción',
                  {
                    'inicio': 'Inicio AAAA-MM-DD',
                    'vencimiento': 'Vencimiento AAAA-MM-DD',
                  },
                  initial: {
                    'inicio': DateTime.now().toIso8601String().substring(0, 10),
                    'vencimiento': DateTime.now()
                        .add(const Duration(days: 30))
                        .toIso8601String()
                        .substring(0, 10),
                  },
                );
                if (v != null)
                  await act(() async {
                    await context.read<Dio>().put(
                      '/api/saas/suscripcion/${context.read<AuthProvider>().operationUser!.idTenant}',
                      data: {
                        ...v,
                        'codigo_plan': p['codigo'],
                        'estado': 'activa',
                      },
                      options: Options(extra: {'replicaBypass': true}),
                    );
                    message = 'Suscripción actualizada.';
                  });
              }),
          ]),
      ],
      if (section == 'Reporte ejecutivo') ...[
        const Text(
          'Consolida cartera, pagos, mora, comisiones y rendimiento del alcance seleccionado.',
        ),
        button(
          'Exportar y compartir PDF',
          exportExecutive,
          icon: Icons.picture_as_pdf,
        ),
      ],
      if (section == 'Notificaciones') ...[
        button(
          'Activar push',
          () => act(() async {
            message = await context.read<PushService>().activate();
          }),
          icon: Icons.notifications_active,
        ),
        button(
          'Enviar prueba',
          () => act(() async {
            final r = await context.read<Dio>().post(
              '/api/notificaciones/prueba',
              options: Options(extra: {'replicaBypass': true}),
            );
            message = r.data['push_enviado'] == true ? 'FCM aceptó la prueba.' : 'Guardada en la bandeja. Falta activar el dispositivo o completar Firebase.';
          }),
        ),
        if (data is Map) ...[
          if ((data['notificaciones'] as List).isEmpty)
            const Text('No hay notificaciones.'),
          for (final n in data['notificaciones'])
            Card(
              child: ListTile(
                leading: Icon(
                  n['leida'] == true
                      ? Icons.mark_email_read
                      : Icons.mark_email_unread,
                ),
                title: Text('${n['titulo']}'),
                subtitle: Text('${n['cuerpo']}'),
                onTap: () => mutate('PUT', '/api/bandeja/${n['id']}/leida'),
              ),
            ),
        ],
      ],
      if (section == 'Sincronización de servicios') ...[
        button(
          'Sincronizar ahora',
          () => act(() async {
            await service.flush();
            data = await service.changes();
          }),
        ),
        if (data is List) ...[
          if ((data as List).isEmpty)
            const Text('Todos los cambios están sincronizados.'),
          for (final r in data)
            card('${r['state']}', [
              Text(
                '${jsonDecode(r['command'])['metodo']} ${jsonDecode(r['command'])['ruta']}',
              ),
              if (r['error'] != null) SelectableText('${r['error']}'),
              button(
                'Descartar propuesta',
                () => act(() async {
                  await service.discard(r['uuid'] as String);
                  data = await service.changes();
                }),
              ),
            ]),
        ],
      ],
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(section == 'Inicio' ? 'Servicios inmobiliarios' : section),
        actions: [
          if (section != 'Inicio')
            IconButton(
              tooltip: 'Volver a servicios',
              onPressed: () => setState(() {
                section = 'Inicio';
                data = null;
              }),
              icon: const Icon(Icons.grid_view),
            ),
          if (section != 'Inicio')
            IconButton(
              tooltip: 'Actualizar',
              onPressed: () => open(section),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }
}

class SalesMap extends StatelessWidget {
  const SalesMap({required this.zones, super.key});
  final List<dynamic> zones;
  @override
  Widget build(BuildContext context) {
    final points = zones
        .where((z) => z['latitud'] != null && z['longitud'] != null)
        .toList();
    return SizedBox(
      height: 330,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: points.isEmpty
              ? const LatLng(-17.7833, -63.1821)
              : LatLng(
                  (points.first['latitud'] as num).toDouble(),
                  (points.first['longitud'] as num).toDouble(),
                ),
          initialZoom: 11,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.inmobiliaria.inmobiliaria_mobile',
          ),
          CircleLayer(
            circles: [
              for (final p in points)
                CircleMarker(
                  point: LatLng(
                    (p['latitud'] as num).toDouble(),
                    (p['longitud'] as num).toDouble(),
                  ),
                  radius: 18 + 35 * (p['intensidad'] as num).toDouble(),
                  color: Color.lerp(
                    Colors.amber,
                    Colors.red,
                    (p['intensidad'] as num).toDouble(),
                  )!.withValues(alpha: 0.5),
                  borderStrokeWidth: 1,
                  borderColor: Colors.red,
                ),
            ],
          ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }
}
