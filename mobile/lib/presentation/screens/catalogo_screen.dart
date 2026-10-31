import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/api_constants.dart';
import '../providers/propiedades_provider.dart';

class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});
  @override
  State<CatalogoScreen> createState() => _CatalogoState();
}

class _CatalogoState extends State<CatalogoScreen> {
  String search = '', operation = 'Todas';
  double? minimum, maximum;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PropiedadesProvider>().fetchPropiedades();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PropiedadesProvider>();
    final items = provider.propiedades
        .where(
          (p) =>
              (operation == 'Todas' || p.tipoOperacion == operation) &&
              (minimum == null || p.precio >= minimum!) &&
              (maximum == null || p.precio <= maximum!) &&
              '${p.titulo} ${p.direccion} ${p.inmobiliaria}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo'),
        actions: [
          IconButton(
            tooltip: 'IA y analítica',
            onPressed: () => context.push('/ia'),
            icon: const Icon(Icons.auto_awesome),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: provider.isLoading ? null : provider.fetchPropiedades,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.fetchPropiedades,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar título, zona o inmobiliaria',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => search = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ['Todas', 'Venta', 'Alquiler']
                  .map(
                    (v) => ChoiceChip(
                      label: Text(v),
                      selected: operation == v,
                      onSelected: (_) => setState(() => operation = v),
                    ),
                  )
                  .toList(),
            ),
            ExpansionTile(
              title: const Text('Precio USD'),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Mínimo'),
                        onChanged: (v) =>
                            setState(() => minimum = double.tryParse(v)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Máximo'),
                        onChanged: (v) =>
                            setState(() => maximum = double.tryParse(v)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (provider.isLoading) const LinearProgressIndicator(),
            if (provider.errorMessage != null) ...[
              Text(provider.errorMessage!),
              TextButton(
                onPressed: () => context.push('/offline'),
                child: const Text('Ver catálogo descargado en Offline'),
              ),
            ],
            Text(
              '${items.length} propiedades',
              key: const ValueKey('catalog-count'),
            ),
            if (!provider.isLoading &&
                provider.errorMessage == null &&
                items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No hay propiedades para esta selección.'),
              ),
            ...items.map((p) {
              final raw = p.imagenes.firstOrNull?.url;
              final url = raw == null || raw.isEmpty
                  ? null
                  : Uri.parse(ApiConstants.baseUrl).resolve(raw).toString();
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push('/propiedad-detalle', extra: p),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (url != null)
                        Image.network(
                          url,
                          height: 170,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            height: 100,
                            child: Icon(Icons.home, size: 40),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (p.inmobiliaria.isNotEmpty)
                              Text(
                                p.inmobiliaria,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            Text(
                              p.titulo,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(p.direccion),
                            const SizedBox(height: 8),
                            Text(
                              'USD ${p.precio.toStringAsFixed(2)} · ${p.tipoOperacion}',
                            ),
                            Text(p.estado),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
