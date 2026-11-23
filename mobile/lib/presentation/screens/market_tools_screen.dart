import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/currency_math.dart';
import '../../data/services/sprint4_service.dart';
import '../../data/services/api_error.dart';
import '../widgets/company_scope.dart';

class MarketToolsScreen extends StatefulWidget {
  const MarketToolsScreen({this.predictions = false, super.key});
  final bool predictions;
  @override
  State<MarketToolsScreen> createState() => _MarketToolsState();
}

class _MarketToolsState extends State<MarketToolsScreen> {
  final amount = TextEditingController(text: '100'),
      manual = TextEditingController();
  static const currencies = ['USD', 'BOB', 'EUR', 'BRL', 'CLP', 'PEN'];
  String origin = 'USD', target = 'BOB', mode = 'real', error = '';
  int horizon = 3, generation = 0;
  bool busy = false;
  Map<String, dynamic>? data;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    amount.dispose();
    manual.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      busy = true;
      error = '';
      if (widget.predictions) data = null;
    });
    try {
      final result = await context.read<Sprint4Service>().get(
        widget.predictions ? '/api/predicciones' : '/api/moneda',
        params: widget.predictions && mode == 'demo' ? {'modo': 'demo'} : null,
      );
      if (!mounted || request != generation) return;
      setState(() => data = Map<String, dynamic>.from(result));
    } catch (e) {
      if (mounted && request == generation) setState(() => error = apiError(e));
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }

  String? converted() {
    if (manual.text.trim().isNotEmpty)
      return currencyConvert(amount.text, '1', manual.text);
    if (origin == target) return currencyConvert(amount.text, '1', '1');
    if (data == null) return null;
    return currencyConvert(
      amount.text,
      '${data!['tasas'][origin]}',
      '${data!['tasas'][target]}',
    );
  }

  Widget currencyPicker(
    String label,
    String value,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    key: ValueKey('$label-$value'),
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: currencies
        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
        .toList(),
    onChanged: (v) {
      if (v != null)
        setState(() {
          change(v);
          manual.clear();
        });
    },
  );
  Future<void> export() async {
    final rows = ['modo,serie,mes,estimado'];
    for (final key in ['ventas', 'demanda']) {
      for (final row in (data![key]['proyeccion'] as List).take(horizon)) {
        rows.add('${data!['modo']},$key,${row['mes']},${row['cantidad']}');
      }
    }
    try {
      await Share.shareXFiles([
        XFile.fromData(
          utf8.encode('\uFEFF${rows.join('\r\n')}'),
          mimeType: 'text/csv',
          name: 'predicciones.csv',
        ),
      ]);
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    }
  }

  List<Widget> predictionWidgets() => [
    DropdownButtonFormField<String>(
      initialValue: mode,
      decoration: const InputDecoration(labelText: 'Datos del modelo'),
      isExpanded: true,
      items: const [
        DropdownMenuItem(
          value: 'real',
          child: Text('Historial de esta selección'),
        ),
        DropdownMenuItem(value: 'demo', child: Text('Escenario académico')),
      ],
      onChanged: (v) {
        if (v != null) {
          setState(() => mode = v);
          load();
        }
      },
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<int>(
      initialValue: horizon,
      decoration: const InputDecoration(labelText: 'Horizonte'),
      items: [1, 3, 6]
          .map((m) => DropdownMenuItem(value: m, child: Text('$m meses')))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => horizon = v);
      },
    ),
    if (data != null) ...[
      Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data!['modo'] == 'demo'
                    ? 'DEMOSTRACIÓN · DATOS SINTÉTICOS'
                    : 'Historial del alcance seleccionado',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('${data!['advertencia']}'),
              Text(
                'Actualización: ${data!['generado_en']} · Hasta: ${data!['hasta']}',
              ),
            ],
          ),
        ),
      ),
      for (final key in ['ventas', 'demanda'])
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  key == 'ventas' ? 'Ventas' : 'Demanda: visitas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('${data!['definiciones'][key]}'),
                Text(
                  '${data![key]['eventos']} eventos en ${data![key]['meses_entrenamiento']} meses.',
                ),
                if (data![key]['estado'] != 'calculado')
                  const Text(
                    'Historial insuficiente. Se requieren al menos 6 meses y 6 eventos. Puedes probar el escenario académico.',
                  ),
                if (data![key]['estado'] == 'calculado') ...[
                  Text(
                    '${data![key]['modelo']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'MAE temporal: ${data![key]['mae_validacion']} · Base: ${data![key]['mae_base']} · Ridge: ${data![key]['mae_modelo_ml']}',
                  ),
                  for (final row in (data![key]['proyeccion'] as List).take(
                    horizon,
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${row['mes']}'),
                      trailing: Text('${row['cantidad']} estimados'),
                    ),
                ],
                ExpansionTile(
                  title: const Text('Ver historial mensual'),
                  children: [
                    for (final row in data![key]['historial'])
                      ListTile(
                        title: Text('${row['mes']}'),
                        trailing: Text('${row['cantidad']}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: export,
        icon: const Icon(Icons.download),
        label: const Text('Exportar proyección CSV'),
      ),
      const Text(
        'Sin conexión se consulta el último cálculo descargado. Entrenar y actualizar el modelo requiere Internet.',
      ),
    ],
  ];
  List<Widget> currencyWidgets() => [
    TextField(
      controller: amount,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Monto a convertir'),
      onChanged: (_) => setState(() {}),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(child: currencyPicker('Origen', origin, (v) => origin = v)),
        IconButton(
          tooltip: 'Invertir monedas',
          icon: const Icon(Icons.swap_horiz),
          onPressed: () => setState(() {
            final old = origin;
            origin = target;
            target = old;
            manual.clear();
          }),
        ),
        Expanded(child: currencyPicker('Destino', target, (v) => target = v)),
      ],
    ),
    ExpansionTile(
      title: const Text('Usar una tasa manual'),
      children: [
        TextField(
          controller: manual,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '1 $origin = unidades de $target',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              converted() == null
                  ? 'Revisa el monto y las tasas'
                  : '${converted()} $target',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            Text(
              manual.text.trim().isNotEmpty
                  ? 'Conversión con la tasa manual ingresada.'
                  : 'Conversión con las tasas de referencia descargadas.',
            ),
          ],
        ),
      ),
    ),
    if (data != null) ...[
      if (data!['vencidas'] == true ||
          DateTime.now().millisecondsSinceEpoch / 1000 >=
              (data!['proxima_actualizacion_unix'] as num))
        const Text(
          'La tasa guardada está vencida; revisa su fecha antes de usarla.',
        ),
      Text('Fecha de la tasa: ${data!['actualizado_en']}'),
      SelectableText('Rates By ${data!['fuente']} · ${data!['fuente_url']}'),
      Text('${data!['aviso']}'),
      for (final c in currencies)
        ListTile(
          title: Text(c),
          trailing: Text('${data!['tasas'][c]} por USD'),
        ),
    ],
    const Text(
      'USD · BOB (boliviano) · EUR (euro) · BRL (real) · CLP (peso chileno) · PEN (sol). Sin conexión puedes convertir con la última descarga o ingresar una tasa manual. Contratos y pagos conservan sus importes originales en USD.',
    ),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.predictions
            ? 'Predicción de ventas y demanda'
            : 'Conversión multimoneda',
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
                if (busy) const LinearProgressIndicator(),
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(error),
                  ),
                ...widget.predictions ? predictionWidgets() : currencyWidgets(),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
