import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/services/reportes_service.dart';
import '../../data/services/api_error.dart';
import '../providers/auth_provider.dart';
import '../widgets/report_table.dart';

class ReportesDinamicosScreen extends StatefulWidget {
  const ReportesDinamicosScreen({super.key});
  @override
  State<ReportesDinamicosScreen> createState() => _ReportesState();
}

class _ReportesState extends State<ReportesDinamicosScreen> {
  static const fields = {
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
  final prompt = TextEditingController();
  final name = TextEditingController();
  final speech = SpeechToText();
  String entity = 'propiedades';
  List<String> selected = ['titulo', 'precio', 'estado'];
  List<Map<String, dynamic>> filters = [];
  String sort = 'precio', direction = 'asc', message = '';
  List<Map<String, dynamic>> saved = [], rows = [];
  List<String> columns = [];
  bool busy = false, generated = false;
  ReportesService get service => ReportesService(context.read<Dio>());
  Map<String, dynamic> get config => {
    'entidad': entity,
    'columnas': selected,
    'filtros': filters,
    'orden': {'columna': sort, 'direccion': direction},
    'limite': 500,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadSaved());
  }

  @override
  void dispose() {
    speech.cancel();
    prompt.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await task();
    } catch (error) {
      if (mounted) setState(() => message = apiError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> loadSaved() async {
    try {
      final result = await service.guardados();
      if (mounted) setState(() => saved = result);
    } catch (error) {
      if (mounted) setState(() => message = apiError(error));
    }
  }

  void apply(Map<String, dynamic> c) {
    final next = c['entidad']?.toString() ?? 'propiedades';
    if (!fields.containsKey(next)) throw StateError('Entidad no soportada.');
    final order = c['orden'] is Map ? c['orden'] as Map : {};
    setState(() {
      entity = next;
      selected = List<String>.from(c['columnas'] ?? [])
          .where(fields[next]!.contains)
          .toList();
      filters = (c['filtros'] as List? ?? [])
          .map((f) => Map<String, dynamic>.from(f))
          .toList();
      sort =
          (order['columna'] ??
                  c['ordenColumna'] ??
                  c['orden_columna'] ??
                  fields[next]!.first)
              .toString();
      if (!fields[next]!.contains(sort)) sort = fields[next]!.first;
      direction =
          (order['direccion'] ?? c['ordenDireccion'] ?? c['orden_direccion']) ==
              'desc'
          ? 'desc'
          : 'asc';
      generated = false;
    });
  }

  Future<void> generate() async {
    if (selected.isEmpty) throw StateError('Selecciona al menos una columna.');
    final result = await service.generar(config);
    if (!mounted) return;
    setState(() {
      columns = List<String>.from(result['columnas'] ?? selected);
      rows = (result['data'] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      generated = true;
      message = result['truncado'] == true
          ? 'Se muestran los primeros 500 registros. Usa filtros para acotar el reporte.'
          : '';
    });
  }

  Future<void> voice() async {
    if (speech.isListening) {
      await speech.stop();
      if (mounted) setState(() {});
      return;
    }
    try {
      final available = await speech.initialize(
        onError: (e) {
          if (mounted)
            setState(
              () => message =
                  'Dictado no disponible. Puedes escribir la solicitud.',
            );
        },
      );
      if (!available)
        throw StateError(
          'Dictado no disponible. Puedes escribir la solicitud.',
        );
      final locales = await speech.locales();
      if (!mounted) return;
      final spanish = locales.where((l) => l.localeId.startsWith('es')).firstOrNull;
      await speech.listen(
        listenOptions: SpeechListenOptions(localeId: spanish?.localeId),
        onResult: (result) {
          if (mounted) setState(() => prompt.text = result.recognizedWords);
        },
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => message = apiError(error));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reportes dinámicos')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.watch<AuthProvider>().scopeLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: prompt,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Solicitar reporte con IA',
            hintText: 'Propiedades disponibles ordenadas por precio',
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : voice,
              icon: Icon(speech.isListening ? Icons.stop : Icons.mic),
              label: const Text('Dictar'),
            ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      if (prompt.text.trim().isEmpty)
                        throw StateError('Escribe o dicta una solicitud.');
                      final c = await service.interpretar(prompt.text.trim());
                      if (!mounted) return;
                      apply(c);
                      await generate();
                    }),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generar con IA'),
            ),
          ],
        ),
        const Divider(height: 32),
        DropdownButtonFormField<String>(
          key: ValueKey(entity),
          initialValue: entity,
          decoration: const InputDecoration(labelText: 'Entidad'),
          items: fields.keys
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: busy
              ? null
              : (v) {
                  if (v != null) apply({'entidad': v, 'columnas': fields[v]});
                },
        ),
        const SizedBox(height: 12),
        const Text('Columnas'),
        Wrap(
          spacing: 6,
          children: fields[entity]!
              .map(
                (c) => FilterChip(
                  label: Text(c),
                  selected: selected.contains(c),
                  onSelected: busy
                      ? null
                      : (v) => setState(() {
                          v ? selected.add(c) : selected.remove(c);
                        }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        for (final (index, filter) in filters.indexed)
          Padding(
            key: ObjectKey(filter),
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            fields[entity]!.contains(filter['columna'])
                            ? filter['columna']
                            : fields[entity]!.first,
                        decoration: const InputDecoration(
                          labelText: 'Filtrar columna',
                        ),
                        items: fields[entity]!
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (v) => setState(() => filter['columna'] = v),
                      ),
                    ),
                    IconButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => filters.removeAt(index)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: filter['operador'],
                        items:
                            const {
                                  'eq': 'Igual',
                                  'like': 'Contiene',
                                  'gt': 'Mayor',
                                  'gte': 'Mayor o igual',
                                  'lt': 'Menor',
                                  'lte': 'Menor o igual',
                                }.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                                )
                                .toList(),
                        onChanged: busy
                            ? null
                            : (v) => setState(() => filter['operador'] = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: filter['valor']?.toString() ?? '',
                        decoration: const InputDecoration(labelText: 'Valor'),
                        onChanged: (v) => filter['valor'] = v,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: busy
              ? null
              : () => setState(
                  () => filters.add({
                    'columna': fields[entity]!.first,
                    'operador': 'eq',
                    'valor': '',
                  }),
                ),
          icon: const Icon(Icons.add),
          label: const Text('Añadir filtro'),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('$entity/$sort'),
          initialValue: sort,
          decoration: const InputDecoration(labelText: 'Ordenar por'),
          items: fields[entity]!
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: busy ? null : (v) => setState(() => sort = v!),
        ),
        SwitchListTile(
          title: const Text('Orden descendente'),
          value: direction == 'desc',
          onChanged: busy
              ? null
              : (v) => setState(() => direction = v ? 'desc' : 'asc'),
        ),
        FilledButton(
          onPressed: busy ? null : () => run(generate),
          child: const Text('Generar reporte'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(message, key: const ValueKey('report-message')),
          ),
        if (generated)
          ReportTable(
            columns: columns,
            rows: rows,
            title:
                'Reporte de $entity · ${context.read<AuthProvider>().scopeLabel}',
          ),
        const Divider(height: 32),
        if (context.watch<AuthProvider>().canWrite) ...[
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Nombre de la configuración',
            ),
          ),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => run(() async {
                    if (name.text.trim().isEmpty)
                      throw StateError('Escribe un nombre.');
                    await service.guardar(name.text.trim(), config);
                    await loadSaved();
                    if (mounted)
                      setState(() => message = 'Configuración guardada.');
                  }),
            child: const Text('Guardar configuración'),
          ),
        ] else
          const Text(
            'Selecciona una inmobiliaria para guardar una configuración.',
          ),
        ListTile(
          title: const Text('Configuraciones guardadas'),
          trailing: IconButton(
            onPressed: busy ? null : loadSaved,
            icon: const Icon(Icons.refresh),
          ),
        ),
        ...saved.map(
          (r) => ListTile(
            title: Text(r['nombre'].toString()),
            trailing: const Icon(Icons.play_arrow),
            onTap: busy
                ? null
                : () => run(() async {
                    final raw = r['configuracion'];
                    apply(
                      Map<String, dynamic>.from(
                        raw is String ? jsonDecode(raw) : raw,
                      ),
                    );
                    await generate();
                  }),
          ),
        ),
      ],
    ),
  );
}
