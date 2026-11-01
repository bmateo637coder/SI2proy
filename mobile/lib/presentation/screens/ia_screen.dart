import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/ia_service.dart';
import '../../data/services/api_error.dart';
import '../providers/auth_provider.dart';
import '../widgets/company_scope.dart';
import '../widgets/report_table.dart';

class IaScreen extends StatefulWidget {
  const IaScreen({super.key});
  @override
  State<IaScreen> createState() => _IaState();
}

class _IaState extends State<IaScreen> {
  final prompt = TextEditingController(
    text: 'Cantidad de propiedades por inmobiliaria y estado',
  );
  final chat = TextEditingController();
  final title = TextEditingController();
  final address = TextEditingController();
  final price = TextEditingController();
  bool busy = false;
  String message = '',
      kind = 'cartera_estado',
      operation = 'Venta',
      description = '';
  DateTime? from, to;
  int? branch;
  List<Map<String, dynamic>> branches = [];
  Map<String, dynamic>? status, report, ml;
  List<Map<String, dynamic>> recommendations = [];
  final List<Map<String, String>> conversation = [];
  IaService get api => IaService(context.read<Dio>());
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => run(() async {
        final result = await api.get('/api/ia/estado');
        if (mounted) setState(() => status = result);
        if (!mounted) return;
        final response = await context.read<Dio>().get('/api/saas/sucursales');
        if (mounted)
          setState(
            () => branches = (response.data as List)
                .map((b) => Map<String, dynamic>.from(b))
                .toList(),
          );
      }),
    );
  }

  @override
  void dispose() {
    for (final c in [prompt, chat, title, address, price]) {
      c.dispose();
    }
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

  String date(DateTime d) => d.toIso8601String().split('T').first;
  Future<void> chooseDate(bool first) async {
    final value = await showDatePicker(
      context: context,
      initialDate: (first ? from : to) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted)
      setState(() {
        if (first) {
          from = value;
        } else {
          to = value;
        }
      });
  }

  Future<void> generate(bool natural) async {
    if (natural && prompt.text.trim().isEmpty)
      throw StateError('Escribe la consulta.');
    if (from != null && to != null && from!.isAfter(to!))
      throw StateError('La fecha inicial debe ser anterior a la final.');
    final result = await api.post(
      natural ? '/api/analitica/reporte' : '/api/analitica/convencional',
      natural
          ? {'texto': prompt.text.trim()}
          : {
              'tipo': kind,
              if (from != null) 'desde': date(from!),
              if (to != null) 'hasta': date(to!),
              if (branch != null) 'id_sucursal': branch,
            },
    );
    if (mounted) setState(() => report = result);
  }

  Widget reportView(Map<String, dynamic> data) {
    final cols = List<String>.from(data['columnas'] ?? []);
    final rows = (data['filas'] as List? ?? [])
        .map(
          (r) => r is Map
              ? Map<String, dynamic>.from(r)
              : Map<String, dynamic>.fromIterables(cols, List<dynamic>.from(r)),
        )
        .toList();
    final numeric = cols.where((c) => rows.any((r) => r[c] is num)).lastOrNull;
    final maximum = numeric == null
        ? 0.0
        : rows.fold<double>(
            0,
            (p, r) => math.max(
              p,
              (num.tryParse('${r[numeric]}') ?? 0).abs().toDouble(),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data['titulo'] ?? 'Resultados'}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (data['resumen'] != null) SelectableText('${data['resumen']}'),
        if (data['interprete'] != null)
          Text('Interpretación: ${data['interprete']}'),
        if (numeric != null && maximum > 0)
          ...rows
              .take(15)
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cols.where((c) => c != numeric).map((c) => r[c] ?? '').join(' · ')}: ${r[numeric]}',
                      ),
                      LinearProgressIndicator(
                        value:
                            ((num.tryParse('${r[numeric]}') ?? 0).abs() /
                                    maximum)
                                .clamp(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
        ReportTable(
          columns: cols,
          rows: rows,
          title:
              '${data['titulo'] ?? 'Reporte'} · ${context.read<AuthProvider>().scopeLabel}',
        ),
      ],
    );
  }

  Widget content(List<Widget> children) => ListView(
    padding: const EdgeInsets.all(16),
    children: children.expand((w) => [w, const SizedBox(height: 12)]).toList(),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('IA y analítica'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Reportes'),
            Tab(text: 'Asistente'),
            Tab(text: 'Propiedades'),
            Tab(text: 'Predicciones'),
          ],
        ),
      ),
      body: Column(
        children: [
          const CompanyScope(),
          if (status?['sin_conexion'] == true)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Modo local: reportes, reglas de texto, plantillas y consultas sobre los datos descargados. Gemini y el entrenamiento de modelos necesitan Internet. Las predicciones guardadas corresponden a su última actualización.',
              ),
            ),
          if (busy) const LinearProgressIndicator(),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(message, key: const ValueKey('ai-message')),
            ),
          Expanded(
            child: TabBarView(
              children: [
                content([
                  Text(
                    context.watch<AuthProvider>().scopeLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextField(
                    controller: prompt,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reporte en lenguaje natural',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : () => run(() => generate(true)),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Consultar con IA'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(
                      labelText: 'Reporte convencional',
                    ),
                    items:
                        const {
                              'ventas_sucursal': 'Ventas por sucursal',
                              'ingresos_semana': 'Ingresos semanales',
                              'cartera_estado': 'Cartera por estado',
                              'ranking_agentes': 'Ranking de agentes',
                              'reservas_sucursal': 'Reservas por sucursal',
                            }.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                    onChanged: busy ? null : (v) => setState(() => kind = v!),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: branch ?? 0,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sucursal'),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text('Todas las sucursales'),
                      ),
                      ...branches.map(
                        (b) => DropdownMenuItem(
                          value: b['id_sucursal'] as int,
                          child: Text(
                            '${b['inmobiliaria'] ?? ''} · ${b['nombre']}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() => branch = v == 0 ? null : v),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: busy ? null : () => chooseDate(true),
                        child: Text(from == null ? 'Desde' : date(from!)),
                      ),
                      OutlinedButton(
                        onPressed: busy ? null : () => chooseDate(false),
                        child: Text(to == null ? 'Hasta' : date(to!)),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                from = null;
                                to = null;
                              }),
                        child: const Text('Limpiar fechas'),
                      ),
                    ],
                  ),
                  FilledButton(
                    onPressed: busy ? null : () => run(() => generate(false)),
                    child: const Text('Generar reporte convencional'),
                  ),
                  if (report != null) reportView(report!),
                ]),
                content([
                  Text(
                    'Gemini: ${status?['configurada'] == true ? 'configurado' : 'consultando / no configurado'} · ${status?['modelo'] ?? ''}',
                  ),
                  const Text(
                    'La IA necesita conexión. La disponibilidad depende del plan de la inmobiliaria seleccionada; el superadministrador puede consultar el conjunto de la plataforma.',
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            final result = await api.post('/api/ia/probar', {});
                            if (mounted)
                              setState(
                                () => message =
                                    'Prueba del proveedor: ${result['mensaje'] ?? result['respuesta'] ?? result['estado'] ?? 'completada'}',
                              );
                          }),
                    child: const Text('Comprobar conexión con IA'),
                  ),
                  ...conversation.map(
                    (m) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText('${m['role']}: ${m['text']}'),
                      ),
                    ),
                  ),
                  TextField(
                    controller: chat,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Pregunta sobre las propiedades',
                    ),
                  ),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            final question = chat.text.trim();
                            if (question.isEmpty)
                              throw StateError('Escribe una pregunta.');
                            final result = await api.post('/api/ia/chat', {
                              'mensaje': question,
                            });
                            if (mounted)
                              setState(() {
                                conversation.addAll([
                                  {'role': 'Tú', 'text': question},
                                  {
                                    'role': 'Asistente',
                                    'text': '${result['respuesta']}',
                                  },
                                ]);
                                chat.clear();
                              });
                          }),
                    child: const Text('Enviar pregunta'),
                  ),
                ]),
                content([
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            final result = await api.post(
                              '/api/ia/recomendar',
                              {'limite': 8},
                            );
                            if (mounted)
                              setState(
                                () => recommendations =
                                    (result['recomendaciones'] as List? ?? [])
                                        .map(
                                          (r) => Map<String, dynamic>.from(r),
                                        )
                                        .toList(),
                              );
                          }),
                    child: const Text('Obtener recomendaciones'),
                  ),
                  const Text(
                    'Recomendaciones calculadas a partir del catálogo disponible.',
                  ),
                  ...recommendations.map(
                    (r) => Card(
                      child: ListTile(
                        title: Text('${r['titulo']}'),
                        subtitle: Text(
                          '${r['inmobiliaria'] ?? ''}\n${r['direccion']}\nUSD ${r['precio']} · ${r['tipo_operacion']}',
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  Text(
                    'Generar descripción',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (!context.watch<AuthProvider>().canWrite)
                    const Text(
                      'Selecciona una inmobiliaria concreta para generar una descripción.',
                    ),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  TextField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Dirección'),
                  ),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Precio USD'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: operation,
                    items: ['Venta', 'Alquiler']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() => operation = v!),
                  ),
                  FilledButton(
                    onPressed: busy || !context.watch<AuthProvider>().canWrite
                        ? null
                        : () => run(() async {
                            final amount = double.tryParse(price.text.trim());
                            if (title.text.trim().isEmpty ||
                                address.text.trim().isEmpty ||
                                amount == null ||
                                amount <= 0)
                              throw StateError(
                                'Completa título, dirección y un precio positivo.',
                              );
                            final result = await api.post(
                              '/api/ia/generar-descripcion',
                              {
                                'titulo': title.text.trim(),
                                'direccion': address.text.trim(),
                                'precio': amount,
                                'tipo_operacion': operation,
                              },
                            );
                            if (mounted)
                              setState(
                                () => description = '${result['descripcion']}',
                              );
                          }),
                    child: const Text('Generar descripción con IA'),
                  ),
                  if (description.isNotEmpty) SelectableText(description),
                ]),
                content([
                  const Text(
                    'Modelo académico entrenado con datos sintéticos. Las estimaciones sirven para demostración y no sustituyen una tasación.',
                  ),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            final result = await api.get(
                              '/api/analitica/dashboard',
                            );
                            if (mounted) setState(() => ml = result);
                          }),
                    child: const Text('Calcular predicciones y grupos'),
                  ),
                  if (ml != null) ...[
                    ...Map<String, dynamic>.from(ml!['metricas'] ?? {}).entries
                        .map(
                          (e) => ListTile(
                            title: Text(e.key),
                            subtitle: Text('${e.value}'),
                          ),
                        ),
                    Text(
                      'Propiedades omitidas: ${ml!['omitidas'] ?? 0}\n${ml!['criterio'] ?? ''}',
                    ),
                    ReportTable(
                      columns: const [
                        'inmobiliaria',
                        'id_propiedad',
                        'precio_publicado',
                        'precio_estimado_sintetico',
                        'grupo',
                        'diferencia_porcentaje',
                      ],
                      rows: (ml!['propiedades'] as List? ?? [])
                          .map((p) => Map<String, dynamic>.from(p))
                          .toList(),
                      title:
                          'Predicciones académicas · ${context.read<AuthProvider>().scopeLabel}',
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
