import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../widgets/raices_map.dart';

import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/services/sprint4_service.dart';
import '../../data/services/push_service.dart';
import '../../data/models/propiedad_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/company_scope.dart';
import '../widgets/workspace_form.dart';

class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key, this.initialSection = 'Inicio'});
  final String initialSection;
  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialSection != 'Inicio') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) open(widget.initialSection);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ServiciosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) open(widget.initialSection);
      });
    }
  }

  String section = 'Inicio',
      message = '',
      metric = 'cierres',
      answer = '',
      mode = '';
  bool loading = false;
  bool _actionInProgress = false;
  int _loadGeneration = 0;
  dynamic data;
  List<dynamic> properties = [];
  int? propertyId;
  final text = TextEditingController();
  final question = TextEditingController();
  Sprint4Service get service => context.read<Sprint4Service>();
  bool get staff => service.staff;
  Future<void> act(Future<void> Function() work) async {
    if (loading) return;
    _actionInProgress = true;
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
      _actionInProgress = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> open(String name) async {
    if (_actionInProgress || !mounted) return;
    final generation = ++_loadGeneration;
    setState(() {
      section = name;
      loading = true;
      message = '';
      data = null;
      answer = '';
    });
    try {
      dynamic result;
      List<dynamic>? nextProperties;
      final paths = <String, String>{
        'Favoritos': '/api/favoritos',
        'Alertas': '/api/alertas',
        'Recomendaciones': '/api/recomendaciones',
        'Mi cuenta': '/api/mi-cuenta',
        'Visitas': '/api/visitas',
        'Mantenimiento': '/api/mantenimiento',
        'Costos de mantenimiento': '/api/mantenimiento/costos/resumen',
        'Gerencia': '/api/gerencia/dashboard',
        'Mapa de ventas': '/api/analitica/zonas',
        'Comisiones': '/api/comisiones',
        'Promociones': '/api/promociones',
        'Notificaciones': '/api/bandeja',
        'Plan y suscripción': '/api/saas/planes',
        'Reporte ejecutivo': '/api/reportes/ejecutivo',
      };
      if (paths.containsKey(name))
        result = await service.get(
          paths[name]!,
          params: name == 'Mapa de ventas' ? {'metrica': metric} : null,
        );
      if ([
        'Búsqueda',
        'Asistente e IA',
        'Promociones',
        'Mantenimiento',
      ].contains(name)) {
        nextProperties = List.from(
          await service.get(
            name == 'Mantenimiento'
                ? '/api/mantenimiento/mis-inmuebles'
                : '/modulo_inmuebles/propiedades/catalogo',
          ),
        );
      }
      if (name == 'Sincronización de servicios')
        result = await service.changes();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        data = result;
        if (nextProperties != null) {
          properties = nextProperties;
          if (!properties.any((p) => p['id_propiedad'] == propertyId))
            propertyId = null;
        }
      });
    } catch (_) {
      if (mounted && generation == _loadGeneration)
        setState(
          () => message = 'No se pudo cargar esta sección. Revisa la conexión y vuelve a intentar.',
        );
    } finally {
      if (mounted && generation == _loadGeneration)
        setState(() => loading = false);
    }
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
    if (!context.read<AuthProvider>().canWrite &&
        [
          '/api/mantenimiento',
          '/api/comisiones',
          '/api/promociones',
          '/api/visitas',
        ].any(path.startsWith)) {
      setState(
        () => message = 'Selecciona una inmobiliaria concreta antes de guardar este cambio.',
      );
      return;
    }
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

  Widget metricCards(Map<String, dynamic> values) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final e in values.entries)
          SizedBox(
            width: (constraints.maxWidth - 10) / 2,
            height: 132,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${e.value}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget bars(String title, Map values) {
    final numbers = values.values
        .map((v) => double.tryParse('$v') ?? 0)
        .toList();
    final max = numbers.fold<double>(1, (a, b) => a > b ? a : b);
    return card(title, [
      if (values.isEmpty) const Text('Sin movimientos para este alcance.'),
      for (final entry in values.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${entry.key} · ${entry.value}'),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: ((double.tryParse('${entry.value}') ?? 0) / max)
                    .clamp(0.0, 1.0)
                    .toDouble(),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
    ]);
  }

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

  Future<void> reloadCurrent() =>
      section == 'Detalle de mantenimiento' && data is Map
      ? maintenanceDetail(data['id'] as int)
      : open(section);

  Future<void> scheduleVisit() async {
    await act(() async {
      if (!context.read<AuthProvider>().canWrite)
        throw StateError('Selecciona una inmobiliaria para agendar.');
      final rows = List<Map<String, dynamic>>.from(
        await service.get('/modulo_inmuebles/propiedades/catalogo'),
      );
      final available = rows.where((p) => p['estado'] == 'Disponible').toList();
      if (!mounted) return;
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(c).height * .7,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Seleccionar inmueble',
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                if (available.isEmpty)
                  const ListTile(title: Text('No hay inmuebles disponibles.')),
                for (final p in available)
                  ListTile(
                    title: Text('${p['titulo']}'),
                    subtitle: Text('${p['tipo_operacion']} · ${p['precio']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(c, p),
                  ),
              ],
            ),
          ),
        ),
      );
      if (picked != null && mounted) {
        await context.push(
          '/agendar-visita',
          extra: PropiedadModel.fromJson(picked),
        );
        if (mounted) data = await service.get('/api/visitas');
      }
    });
  }

  Future<void> editMaintenance(Map row) async {
    if (!context.read<AuthProvider>().canWrite) {
      setState(
        () => message = 'Selecciona una inmobiliaria concreta para gestionar la incidencia.',
      );
      return;
    }
    final originalScope = context.read<AuthProvider>().scopeKey;
    List<Map<String, dynamic>> users = [];
    await act(() async {
      final agents = List<Map<String, dynamic>>.from(
        await service.get('/modulo_inmuebles/agentes'),
      );
      final agentCis = agents.map((a) => a['ci_usuario']).toSet();
      users =
          List<Map<String, dynamic>>.from(
                await service.get('/gestion_usuarios/usuarios'),
              )
              .where(
                (u) =>
                    [1, 2].contains(u['id_rol']) || agentCis.contains(u['ci']),
              )
              .toList();
    });
    if (!mounted) return;
    await workspaceForm(
      context,
      'Gestionar incidencia',
      [
        const WorkspaceField(
          'categoria',
          'Categoría',
          choices: {
            'Plomeria': 'Plomería',
            'Electricidad': 'Electricidad',
            'Estructura': 'Estructura',
            'Electrodomesticos': 'Electrodomésticos',
            'Seguridad': 'Seguridad',
            'Limpieza y plagas': 'Limpieza y plagas',
            'Otro': 'Otro',
          },
        ),
        const WorkspaceField(
          'urgencia',
          'Urgencia',
          choices: {
            'Baja': 'Baja',
            'Media': 'Media',
            'Alta': 'Alta',
            'Critica': 'Crítica',
          },
        ),
        WorkspaceField(
          'id_responsable',
          'Responsable',
          required: false,
          choices: {for (final u in users) '${u['ci']}': '${u['nombre']}'},
        ),
        const WorkspaceField('contratista', 'Contratista', required: false),
        const WorkspaceField(
          'comentario',
          'Comentario de seguimiento',
          multiline: true,
          required: false,
        ),
      ],
      (v) async {
        if (originalScope != context.read<AuthProvider>().scopeKey)
          throw StateError(
            'Cambió la inmobiliaria. Vuelve a abrir la incidencia.',
          );
        final payload = <String, dynamic>{...v};
        if (payload['id_responsable'] == '') payload.remove('id_responsable');
        final result = await service.mutate(
          'PUT',
          '/api/mantenimiento/${row['id']}',
          payload,
          row['version'] as int?,
        );
        if (!mounted) return;
        setState(
          () => message = result['pendiente'] == true
              ? 'Cambio pendiente de sincronizar.'
              : 'Incidencia actualizada.',
        );
      },
      initial: Map<String, dynamic>.from(row),
    );
    if (mounted) await maintenanceDetail(row['id'] as int);
  }

  Future<void> exportExecutiveCsv() async {
    await act(() async {
      final r = await service.get('/api/reportes/ejecutivo') as Map;
      final rows = <List<dynamic>>[
        ['Indicador', 'Valor'],
        ['Inmuebles', r['cartera']['total']],
        ['Contratos', r['ingresos']['contratos']],
        ['Cobrado', r['ingresos']['cobrado_total']],
        ['Por cobrar', r['ingresos']['por_cobrar']],
        ['Vencido', r['ingresos']['vencido']],
        ['Costo mantenimiento', r['mantenimiento']['costo_total']],
        ['Comisiones generadas', r['comisiones']['generadas']],
        ['Comisiones liquidadas', r['comisiones']['cobradas']],
      ];
      final file = File(
        '${(await getTemporaryDirectory()).path}/reporte-ejecutivo.csv',
      );
      await file.writeAsString(
        '\ufeff' +
            rows
                .map(
                  (row) => row
                      .map((v) => '"${'$v'.replaceAll('"', '""')}"')
                      .join(','),
                )
                .join('\r\n'),
      );
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Reporte ejecutivo Raíces');
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
            pw.Text(
              'Costo de mantenimiento: ${report['mantenimiento']['costo_total']}',
            ),
            pw.Text(
              'Comisiones generadas: ${report['comisiones']['generadas']}',
            ),
            pw.Text(
              'Comisiones liquidadas: ${report['comisiones']['cobradas']}',
            ),
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
      'Visitas': Icons.event,
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
              onTap: () => e.key == 'Plan y suscripción'
                  ? context.push('/gestion/planes')
                  : open(e.key),
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
      if (section == 'Visitas' && data is List) ...[
        button('Agendar visita', scheduleVisit, icon: Icons.add),
        if ((data as List).isEmpty)
          const Text('No hay visitas en este alcance.'),
        for (final v in data)
          card('${v['propiedad'] ?? "Visita pendiente"}', [
            Text('${v['fecha_hora']} · ${v['estado']}'),
            Text(
              'Cliente: ${v['cliente'] ?? "Por confirmar"} · Agente: ${v['agente'] ?? "Por confirmar"}',
            ),
            if (['Programada', 'Confirmada'].contains(v['estado']))
              Wrap(
                children: [
                  if (staff)
                    button(
                      'Confirmar',
                      () => mutate('PUT', '/api/visitas/${v['id_visita']}', {
                        'estado': 'Confirmada',
                      }),
                    ),
                  if (staff)
                    button(
                      'Realizada',
                      () => mutate('PUT', '/api/visitas/${v['id_visita']}', {
                        'estado': 'Realizada',
                      }),
                    ),
                  button(
                    'Cancelar',
                    () => mutate('PUT', '/api/visitas/${v['id_visita']}', {
                      'estado': 'Cancelada',
                    }),
                  ),
                ],
              ),
          ]),
      ],
      if (section == 'Mantenimiento') ...[
        button(
          'Costos consolidados',
          () => open('Costos de mantenimiento'),
          icon: Icons.account_balance_wallet_outlined,
        ),
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
                  '${s['inmobiliaria'] ?? ''} · ${s['estado']} · ${s['urgencia']} · ${s['propiedad']}',
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
          Text(
            'Clasificación: ${data['clasificacion_modo'] ?? ''} · ${data['justificacion'] ?? ''}',
          ),
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
            button(
              'Responsable, categoría y urgencia',
              () => editMaintenance(Map.from(data)),
              icon: Icons.tune,
            ),
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
              ListTile(
                title: Text('${c['concepto']}'),
                subtitle: Text('${c['monto']}'),
                trailing: IconButton(
                  tooltip: 'Eliminar costo',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => mutate(
                    'DELETE',
                    '/api/mantenimiento/${data['id']}/costos/${c['id']}',
                    {},
                    data['version'] as int?,
                  ),
                ),
              ),
          ],
          for (final e in data['eventos'] ?? [])
            ListTile(
              title: Text('${e['estado']}'),
              subtitle: Text('${e['detalle']} · ${e['fecha']}'),
            ),
        ]),
      ],
      if (section == 'Costos de mantenimiento' && data is Map) ...[
        card('Costo total de mantenimiento', [
          Text(
            '${data['total_general']}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ]),
        for (final p in data['inmuebles'] ?? [])
          card('${p['propiedad']}', [
            Text('${p['solicitudes']} solicitudes · ${p['abiertas']} abiertas'),
            Text('Total: ${p['costo_total']}'),
            for (final e in (p['por_categoria'] as Map).entries)
              Text('${e.key}: ${e.value}'),
          ]),
      ],
      if (section == 'Gerencia' && data is Map) ...[
        metricCards({
          'Inmuebles': data['cartera']['total'],
          'Cobrado': data['ingresos']['cobrado_total'],
          'Por cobrar': data['ingresos']['por_cobrar'],
          'Vencido': data['ingresos']['vencido'],
          'Mantenimiento abierto': data['mantenimiento']['abiertas'],
          'Costo mantenimiento': data['mantenimiento']['costo_total'],
          'Contratos': data['ingresos']['contratos'],
          'Ocupación %': data['cartera']['ocupacion_pct'],
          'Morosidad %': data['ingresos']['morosidad_pct'],
          'Cuotas vencidas': data['ingresos']['cuotas_vencidas'],
          'Comisiones generadas': data['comisiones']['generadas'],
          'Comisiones liquidadas': data['comisiones']['cobradas'],
          'Visitas próximas': data['visitas']['proximas_7_dias'],
          'Incidencias críticas': data['mantenimiento']['criticas_abiertas'],
        }),
        const SizedBox(height: 12),
        bars('Cartera por estado', Map.from(data['cartera']['por_estado'])),
        bars(
          'Cartera por operación',
          Map.from(data['cartera']['por_operacion']),
        ),
        bars('Ingresos por mes', {
          for (final row in data['ingresos']['por_mes'])
            row['mes']: row['monto'],
        }),
        for (final a in data['rendimiento_agentes'])
          card('${a['agente']} · ${a['inmobiliaria']}', [
            Text(
              '${a['contratos']} contratos · monto ${a['monto_cerrado']} · comisión ${a['comision_generada']}',
            ),
            Text(
              '${a['inmuebles']} inmuebles · ${a['visitas']} visitas · ${a['visitas_realizadas']} realizadas',
            ),
            Text(
              'Comisión liquidada: ${a['comision_cobrada']} · Conversión: ${a['conversion_visitas'] ?? 'Sin visitas'}',
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
          card('${c['agente']} · ${c['inmobiliaria']}', [
            Text('${c['propiedad']} · ${c['monto']} · ${c['estado']}'),
            Text('Base: ${c['base']} · Comisión: ${c['porcentaje']}%'),
            Text(
              'Creada: ${c['creado']} · Liquidación: ${c['liquidada_en'] ?? 'Pendiente'}',
            ),
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
        button(
          'Exportar y compartir CSV',
          exportExecutiveCsv,
          icon: Icons.table_view,
        ),
        const Text(
          'Consolida cartera, pagos, mora, comisiones y rendimiento del alcance seleccionado.',
        ),
        button(
          'Exportar y compartir PDF',
          exportExecutive,
          icon: Icons.picture_as_pdf,
        ),
        if (data is Map) ...[
          card('Cartera', [Text('${data['cartera']['total']} inmuebles')]),
          card('Resumen financiero', [
            Text('Cobrado: ${data['ingresos']['cobrado_total']}'),
            Text('Por cobrar: ${data['ingresos']['por_cobrar']}'),
            Text('Vencido: ${data['ingresos']['vencido']}'),
            Text('Contratos: ${data['ingresos']['contratos']}'),
          ]),
          card('Mantenimiento', [
            Text(
              'Abiertas: ${data['mantenimiento']['abiertas']} · Costo: ${data['mantenimiento']['costo_total']}',
            ),
          ]),
        ],
      ],
      if (section == 'Notificaciones') ...[
        button(
          'Marcar todas como leídas',
          () => mutate('PUT', '/api/bandeja/leer-todas'),
          icon: Icons.done_all,
        ),
        button(
          'Activar avisos',
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
            await context.read<PushService>().pollNow();
            message = r.data['push_enviado'] == true
                ? 'El servicio push aceptó la prueba.'
                : 'Prueba guardada. Si activaste los avisos, revisa las notificaciones del teléfono.';
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
              if (r['state'] == 'conflicto')
                button(
                  'Volver a proponer con la versión mostrada',
                  () => act(() async {
                    await service.rebase(r['uuid'] as String);
                    data = await service.changes();
                  }),
                ),
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
              onPressed: _actionInProgress
                  ? null
                  : () => setState(() {
                      _loadGeneration++;
                      loading = false;
                      section = 'Inicio';
                      data = null;
                    }),
              icon: const Icon(Icons.grid_view),
            ),
          if (section != 'Inicio')
            IconButton(
              tooltip: 'Actualizar',
              onPressed: reloadCurrent,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Column(
        children: [
          const CompanyScope(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: reloadCurrent,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SalesMap extends StatelessWidget {
  const SalesMap({required this.zones, super.key});
  final List<dynamic> zones;
  @override
  Widget build(BuildContext context) {
    final points = <MapPoint>[
      for (var i = 0; i < zones.length; i++)
        if (mapCoordinate(zones[i]['latitud'], zones[i]['longitud']) != null)
          MapPoint(
            id: '$i',
            label: '${zones[i]['zona']} · ${zones[i]['cierres']} cierres',
            point: mapCoordinate(zones[i]['latitud'], zones[i]['longitud'])!,
            intensity:
                double.tryParse('${zones[i]['intensidad']}')?.clamp(0, 1) ?? 0,
          ),
    ];
    void select(MapPoint point) {
      final zone = zones[int.parse(point.id)];
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${zone['zona']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('${zone['inmobiliaria'] ?? ''}'),
                Text(
                  '${zone['inmuebles']} inmuebles · ${zone['cierres']} cierres',
                ),
                Text('Monto cerrado: USD ${zone['monto']}'),
                Text('Precio por m²: ${zone['precio_m2'] ?? 'Sin datos'}'),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaicesMap(points: points, heat: true, height: 330, onSelected: select),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Amarillo: menor valor · Rojo: mayor valor. Toca una zona para consultar sus datos.',
          ),
        ),
        if (points.length < zones.length)
          Text(
            '${zones.length - points.length} zonas sin coordenadas válidas.',
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.fullscreen),
          label: const Text('Ampliar mapa'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Mapa de ventas')),
                body: Padding(
                  padding: const EdgeInsets.all(12),
                  child: RaicesMap(
                    points: points,
                    heat: true,
                    onSelected: select,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
