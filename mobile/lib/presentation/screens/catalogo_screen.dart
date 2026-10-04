import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/api_constants.dart';
import '../providers/propiedades_provider.dart';

class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PropiedadesProvider>().fetchPropiedades();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PropiedadesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Propiedades'),
        centerTitle: true,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${provider.errorMessage}', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => provider.fetchPropiedades(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : provider.propiedades.isEmpty
                  ? const Center(child: Text('No hay propiedades registradas aún.'))
                  : RefreshIndicator(
                      onRefresh: provider.fetchPropiedades,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.propiedades.length,
                        itemBuilder: (context, index) {
                          final prop = provider.propiedades[index];
                          final rawImageUrl = prop.imagenes.isNotEmpty ? prop.imagenes.first.url : null;
                          final imageUrl = rawImageUrl == null || rawImageUrl.isEmpty
                              ? null
                              : (rawImageUrl.startsWith('http')
                                  ? rawImageUrl
                                  : '${ApiConstants.baseUrl}$rawImageUrl');

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (imageUrl != null)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    child: Image.network(
                                      imageUrl,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        height: 200,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    ),
                                    child: const Icon(Icons.image, size: 50, color: Colors.grey),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prop.titulo,
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        prop.direccion,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.grey[600],
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '\$${prop.precio.toStringAsFixed(2)} - ${prop.tipoOperacion}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getColorForEstado(prop.estado).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: _getColorForEstado(prop.estado)),
                                            ),
                                            child: Text(
                                              prop.estado,
                                              style: TextStyle(
                                                color: _getColorForEstado(prop.estado),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Color _getColorForEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'disponible':
        return Colors.green;
      case 'reservada':
        return Colors.orange;
      case 'vendida':
        return Colors.red;
      case 'alquilada':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
