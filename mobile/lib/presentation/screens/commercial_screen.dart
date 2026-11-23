import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/sprint4_service.dart';
import '../../data/services/api_error.dart';
import '../providers/auth_provider.dart';
import '../widgets/company_scope.dart';

const commercialStages = [
  'Nuevo',
  'Contactado',
  'Visita',
  'Negociacion',
  'Ganado',
  'Perdido',
];

class CommercialScreen extends StatefulWidget {
  const CommercialScreen({this.workflow = false, super.key});
  final bool workflow;
  @override
  State<CommercialScreen> createState() => _CommercialState();
}

class _CommercialState extends State<CommercialScreen> {
  final query = TextEditingController(), text = TextEditingController();
  List<dynamic> rows = [], opportunities = [];
  Map<String, dynamic> options = {};
  bool busy = false;
  String error = '', notice = '', status = '';
  int generation = 0;
  int? opportunity, agent;
  bool get readonly {
    final a = context.read<AuthProvider>();
    return a.allTenants || (a.selectedTenant ?? a.user?.idTenant) == null;
  }

  @override
  void initState() {
    super.initState();
    query.addListener(changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  void changed() {
    setState(() {});
  }

  @override
  void dispose() {
    generation++;
    query.removeListener(changed);
    query.dispose();
    text.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final gen = ++generation;
    setState(() {
      busy = true;
      error = '';
      rows = [];
    });
    final service = context.read<Sprint4Service>();
    try {
      final result = await Future.wait([
        service.get(
          widget.workflow ? '/api/workflow-ia' : '/api/oportunidades',
        ),
        service.get('/api/oportunidades/opciones'),
        service.get('/api/oportunidades'),
      ]);
      if (!mounted || gen != generation) return;
      setState(() {
        rows = List.from(result[0] as List);
        options = Map<String, dynamic>.from(result[1] as Map);
        opportunities = List.from(result[2] as List);
      });
    } catch (e) {
      if (mounted && gen == generation) setState(() => error = apiError(e));
    } finally {
      if (mounted && gen == generation) setState(() => busy = false);
    }
  }

  Future<void> write(
    String method,
    String path,
    Map<String, dynamic> data,
  ) async {
    if (readonly || busy) return;
    final gen = generation;
    setState(() {
      busy = true;
      error = '';
      notice = '';
    });
    try {
      final r = await context.read<Sprint4Service>().mutate(
        method,
        path,
        data,
        data['version'] as int?,
      );
      if (!mounted || gen != generation) return;
      setState(
        () => notice = r['pendiente'] == true
            ? 'Guardado en el teléfono; pendiente de sincronización.'
            : 'Cambio guardado.',
      );
      await load();
    } catch (e) {
      if (mounted && gen == generation)
        setState(() {
          error = apiError(e);
          busy = false;
        });
    }
  }

  Map<String, dynamic> payload(Map r) => {
    for (final k in [
      'titulo',
      'contacto',
      'importe',
      'probabilidad',
      'etapa',
      'notas',
      'proximo_contacto',
      'id_cliente',
      'id_propiedad',
      'id_agente',
    ])
      k: r[k],
    if (r['version'] != null) 'version': r['version'],
  };
  Future<void> edit([Map? row]) async {
    final r = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => OpportunityEditor(row: row, options: options),
      ),
    );
    if (!mounted || r == null) return;
    await write(
      row == null ? 'POST' : 'PUT',
      '/api/oportunidades${row == null ? '' : '/${row['id']}'}',
      r,
    );
  }

  Future<void> archive(Map r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Archivar oportunidad?'),
        content: const Text('Se conservará su historial.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted)
      await write('DELETE', '/api/oportunidades/${r['id']}', {
        'version': r['version'] ?? 1,
      });
  }

  List<dynamic> get filtered => rows
      .where(
        (r) =>
            (agent == null || r['id_agente'] == agent) &&
            '${r['titulo']} ${r['contacto']} ${r['inmobiliaria']}'
                .toLowerCase()
                .contains(query.text.trim().toLowerCase()),
      )
      .toList();
  String money(dynamic n) => (double.tryParse('$n') ?? 0).toStringAsFixed(2);
  Widget history(Map r) => ExpansionTile(
    title: const Text('Historial'),
    children: [
      for (final h in r['historial'] as List? ?? [])
        ListTile(
          title: Text('${h['accion']}'),
          subtitle: Text('${h['fecha']} · ${h['usuario']}'),
        ),
    ],
  );
  Widget deal(Map r) => Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r['titulo']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text('${r['inmobiliaria']} · ${r['contacto']}'),
          Text('${money(r['importe'])} USD · ${r['probabilidad']}%'),
          Text('Próximo contacto: ${r['proximo_contacto'] ?? 'Sin programar'}'),
          if (r['pendiente'] == true) const Text('Pendiente de sincronizar'),
          DropdownButtonFormField<String>(
            initialValue: r['etapa'] as String,
            decoration: const InputDecoration(labelText: 'Etapa'),
            items: [
              for (final s in commercialStages)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: readonly || busy
                ? null
                : (s) {
                    if (s != null && s != r['etapa'])
                      write(
                        'PUT',
                        '/api/oportunidades/${r['id']}',
                        payload({...r, 'etapa': s}),
                      );
                  },
          ),
          Wrap(
            children: [
              TextButton(
                onPressed: readonly || busy ? null : () => edit(r),
                child: const Text('Editar'),
              ),
              TextButton(
                onPressed: readonly || busy ? null : () => archive(r),
                child: const Text('Archivar'),
              ),
            ],
          ),
          history(r),
        ],
      ),
    ),
  );
  Widget board() {
    final all = filtered;
    final open = all.where((r) => !['Ganado', 'Perdido'].contains(r['etapa']));
    final total = open.fold<double>(
      0,
      (s, r) => s + (double.tryParse('${r['importe']}') ?? 0),
    );
    final weighted = open.fold<double>(
      0,
      (s, r) =>
          s +
          (double.tryParse('${r['importe']}') ?? 0) *
              (double.tryParse('${r['probabilidad']}') ?? 0) /
              100,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: query,
          decoration: const InputDecoration(
            labelText: 'Buscar oportunidades',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: agent,
          decoration: const InputDecoration(labelText: 'Responsable'),
          items: [
            const DropdownMenuItem<int>(value: null, child: Text('Todos')),
            for (final a in options['agentes'] as List? ?? [])
              DropdownMenuItem<int>(
                value: a['id'] as int,
                child: Text('${a['nombre']}'),
              ),
          ],
          onChanged: (v) => setState(() => agent = v),
        ),
        const SizedBox(height: 12),
        Text(
          '${all.length} oportunidades · Abierto: ${money(total)} USD\nPonderado: ${money(weighted)} USD',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: readonly || busy ? null : () => edit(),
          icon: const Icon(Icons.add),
          label: const Text('Nueva oportunidad'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Desliza para ver las etapas. Usa el selector de cada tarjeta para moverla. Ganado no crea un contrato ni un cobro.',
          ),
        ),
        SizedBox(
          height: 600,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: commercialStages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (c, index) {
              final stage = commercialStages[index];
              final items = all.where((r) => r['etapa'] == stage).toList();
              return Container(
                width: math.min(330, MediaQuery.sizeOf(context).width - 48),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xffedf3f4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$stage · ${items.length}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${money(items.fold<double>(0, (s, r) => s + (double.tryParse('${r['importe']}') ?? 0)))} USD',
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: Text('Sin oportunidades'))
                          : ListView(
                              children: [for (final r in items) deal(r as Map)],
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget workflows() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: text,
        maxLines: 4,
        maxLength: 3000,
        decoration: const InputDecoration(
          labelText: 'Consulta comercial',
          hintText: 'El cliente quiere visitar una casa hoy y conocer las condiciones de compra',
        ),
      ),
      DropdownButtonFormField<int>(
        initialValue: opportunity,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Oportunidad vinculada'),
        items: [
          const DropdownMenuItem<int>(value: null, child: Text('Sin vincular')),
          for (final r in opportunities)
            DropdownMenuItem<int>(
              value: r['id'] as int,
              child: Text('${r['titulo']}', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: busy ? null : (v) => setState(() => opportunity = v),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: readonly || busy
            ? null
            : () {
                if (text.text.trim().length < 5) {
                  setState(() => error = 'Escribe al menos 5 caracteres.');
                  return;
                }
                write('POST', '/api/workflow-ia', {
                  'texto': text.text.trim(),
                  'id_oportunidad': opportunity,
                });
              },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generar plan de seguimiento'),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Gemini clasifica si está disponible; en otro caso se aplican reglas locales identificadas. Revisa las tareas. No se envían mensajes ni se generan contratos automáticamente.',
        ),
      ),
      DropdownButtonFormField<String>(
        initialValue: status,
        decoration: const InputDecoration(labelText: 'Mostrar'),
        items: [
          for (final s in ['', 'Pendiente', 'Completado'])
            DropdownMenuItem(value: s, child: Text(s.isEmpty ? 'Todos' : s)),
        ],
        onChanged: (s) => setState(() => status = s ?? ''),
      ),
      for (final r in rows.where(
        (r) => status.isEmpty || r['estado'] == status,
      ))
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['categoria']} · ${r['urgencia']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('${r['inmobiliaria']} · ${r['estado']}'),
                Text(
                  r['modo'] == 'gemini'
                      ? 'Clasificación Gemini'
                      : r['pendiente'] == true
                      ? 'Reglas locales; pendiente de sincronizar'
                      : 'Reglas locales',
                ),
                Text('${r['texto']}'),
                Text('${r['justificacion']}'),
                if (r['id_oportunidad'] != null)
                  Text('Oportunidad #${r['id_oportunidad']}'),
                for (var i = 0; i < (r['tareas'] as List? ?? []).length; i++)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r['tareas'][i]['titulo']}'),
                    subtitle: Text('Vence: ${r['tareas'][i]['vence']}'),
                    value: r['tareas'][i]['completada'] == true,
                    onChanged: readonly || busy
                        ? null
                        : (v) => write('PUT', '/api/workflow-ia/${r['id']}', {
                            'version': r['version'] ?? 1,
                            'tarea': i,
                            'completada': v == true,
                          }),
                  ),
                history(r as Map),
              ],
            ),
          ),
        ),
      if (rows.isEmpty && !busy)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Todavía no hay planes de seguimiento.'),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.workflow ? 'Workflow inteligente con IA' : 'Embudo comercial',
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        const CompanyScope(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (readonly)
                  const Text(
                    'Vista de todas las inmobiliarias. Selecciona una empresa para registrar cambios.',
                  ),
                if (busy) const LinearProgressIndicator(),
                if (error.isNotEmpty)
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (notice.isNotEmpty) Text(notice),
                const SizedBox(height: 12),
                widget.workflow ? workflows() : board(),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class OpportunityEditor extends StatefulWidget {
  const OpportunityEditor({this.row, required this.options, super.key});
  final Map? row;
  final Map<String, dynamic> options;
  @override
  State<OpportunityEditor> createState() => _OpportunityEditorState();
}

class _OpportunityEditorState extends State<OpportunityEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, contact, amount, probability, notes;
  late Map<String, dynamic> data;
  @override
  void initState() {
    super.initState();
    data = {...widget.row ?? {}, 'etapa': widget.row?['etapa'] ?? 'Nuevo'};
    title = TextEditingController(text: widget.row?['titulo'] as String? ?? '');
    contact = TextEditingController(
      text: widget.row?['contacto'] as String? ?? '',
    );
    amount = TextEditingController(text: '${widget.row?['importe'] ?? 0}');
    probability = TextEditingController(
      text: '${widget.row?['probabilidad'] ?? 10}',
    );
    notes = TextEditingController(text: widget.row?['notas'] as String? ?? '');
  }

  @override
  void dispose() {
    for (final c in [title, contact, amount, probability, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String label,
    TextEditingController c, {
    bool money = false,
    bool percent = false,
    int max = 150,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      maxLines: lines,
      maxLength: max,
      keyboardType: money || percent
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (lines > 1) return null;
        if (money) {
          if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(v ?? ''))
            return 'Usa un importe válido con hasta dos decimales.';
          final n = double.tryParse(v!.replaceAll(',', '.'));
          return n == null || n < 0 || n > 999999999999
              ? 'Importe fuera de rango'
              : null;
        }
        if (percent) {
          final n = int.tryParse(v ?? '');
          return n == null || n < 0 || n > 100
              ? 'Ingresa un entero entre 0 y 100'
              : null;
        }
        return (v ?? '').trim().length < 3
            ? 'Escribe al menos 3 caracteres'
            : null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.row == null ? 'Nueva oportunidad' : 'Editar oportunidad',
      ),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          field('Título de oportunidad', title),
          field('Contacto', contact, max: 200),
          field('Importe USD', amount, money: true, max: 16),
          field('Probabilidad %', probability, percent: true, max: 3),
          DropdownButtonFormField<String>(
            initialValue: data['etapa'] as String,
            decoration: const InputDecoration(labelText: 'Etapa'),
            items: [
              for (final s in commercialStages)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => data['etapa'] = v,
          ),
          const SizedBox(height: 12),
          for (final ref in [
            ('Cliente', 'id_cliente', 'clientes'),
            ('Inmueble', 'id_propiedad', 'propiedades'),
            ('Responsable', 'id_agente', 'agentes'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<int>(
                initialValue: data[ref.$2] as int?,
                isExpanded: true,
                decoration: InputDecoration(labelText: ref.$1),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Sin asignar'),
                  ),
                  for (final r in widget.options[ref.$3] as List? ?? [])
                    DropdownMenuItem<int>(
                      value: r['id'] as int,
                      child: Text(
                        '${r['nombre']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => data[ref.$2] = v,
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Próximo contacto'),
            subtitle: Text('${data['proximo_contacto'] ?? 'Sin programar'}'),
            trailing: IconButton(
              tooltip: 'Limpiar fecha',
              onPressed: () => setState(() => data['proximo_contacto'] = null),
              icon: const Icon(Icons.clear),
            ),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate:
                    DateTime.tryParse('${data['proximo_contacto']}') ??
                    DateTime.now(),
              );
              if (d != null && mounted)
                setState(
                  () => data['proximo_contacto'] = d
                      .toIso8601String()
                      .substring(0, 10),
                );
            },
          ),
          field('Notas', notes, lines: 4, max: 3000),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(context, <String, dynamic>{
                'titulo': title.text.trim(),
                'contacto': contact.text.trim(),
                'importe': amount.text.replaceAll(',', '.'),
                'probabilidad': int.parse(probability.text),
                'notas': notes.text.trim(),
                'etapa': data['etapa'],
                'proximo_contacto': data['proximo_contacto'],
                for (final k in ['id_cliente', 'id_propiedad', 'id_agente'])
                  k: data[k],
                if (data['version'] != null) 'version': data['version'],
              });
            },
            child: const Text('Guardar oportunidad'),
          ),
        ],
      ),
    ),
  );
}
