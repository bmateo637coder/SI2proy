import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/api_constants.dart';
import '../../data/models/propiedad_model.dart';
import '../providers/propiedades_provider.dart';
import '../widgets/company_scope.dart';
import '../widgets/property_image.dart';
import '../widgets/raices_map.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String operation = 'Todas';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PropiedadesProvider>().fetchPropiedades();
    });
  }

  void details(PropiedadModel p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.imagenes.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PropertyImage(
                      Uri.parse('${ApiConstants.baseUrl}/')
                          .resolve(p.imagenes.first.url)
                          .toString(),
                      height: 170,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(p.titulo, style: Theme.of(sheet).textTheme.titleLarge),
                if (p.inmobiliaria.isNotEmpty) Text(p.inmobiliaria),
                Text(p.direccion),
                const SizedBox(height: 8),
                Text(
                  'USD ${p.precio.toStringAsFixed(0)} · ${p.tipoOperacion} · ${p.estado}',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.home_work_outlined),
                  label: const Text('Ver ficha del inmueble'),
                  onPressed: () {
                    Navigator.pop(sheet);
                    context.push('/propiedad-detalle', extra: p);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PropiedadesProvider>();
    final properties = provider.propiedades
        .where((p) => operation == 'Todas' || p.tipoOperacion == operation)
        .toList();
    final located = properties
        .where((p) => mapCoordinate(p.latitud, p.longitud) != null)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de propiedades'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: provider.isLoading ? null : provider.fetchPropiedades,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          const CompanyScope(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${located.length} de ${properties.length} inmuebles ubicados',
                  ),
                ),
                DropdownButton<String>(
                  value: operation,
                  items: ['Todas', 'Venta', 'Alquiler', 'Anticretico']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => operation = v);
                  },
                ),
              ],
            ),
          ),
          if (provider.isLoading) const LinearProgressIndicator(),
          if (provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(provider.errorMessage!),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: RaicesMap(
                points: [
                  for (final p in located)
                    MapPoint(
                      id: '${p.idPropiedad}',
                      label: p.titulo,
                      point: mapCoordinate(p.latitud, p.longitud)!,
                    ),
                ],
                onSelected: (point) => details(
                  located.firstWhere((p) => '${p.idPropiedad}' == point.id),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                '${properties.length - located.length} sin coordenadas. Toca un marcador para abrir su ficha. El mapa base necesita conexión.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
