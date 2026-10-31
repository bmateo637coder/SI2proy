import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/propiedades_provider.dart';
import '../../core/config/api_constants.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Centro por defecto (Santa Cruz)
  final LatLng _defaultCenter = const LatLng(-17.7833, -63.1821);
  LatLng? _userLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<PropiedadesProvider>().propiedades.isEmpty) {
        context.read<PropiedadesProvider>().fetchPropiedades();
      }
      _getUserLocation(moveMap: true);
    });
  }

  Future<void> _getUserLocation({bool moveMap = false}) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
    });

    if (moveMap && _userLocation != null) {
      _mapController.move(_userLocation!, 15.0);
    }
  }

  void _showPropiedadDetalle(BuildContext context, dynamic prop) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final imageUrl = prop.imagenes.isNotEmpty
            ? '${ApiConstants.baseUrl}${prop.imagenes.first.url}'
            : null;

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 150,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.home_work,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.home_work,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                prop.titulo,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      prop.direccion,
                      style: const TextStyle(color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '\$${prop.precio.toStringAsFixed(2)} - ${prop.tipoOperacion}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar el bottom sheet
                  context.push('/propiedad-detalle', extra: prop);
                },
                child: const Text('Ver más detalles'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PropiedadesProvider>();

    // Generar marcadores
    final List<Marker> markers = provider.propiedades.map((prop) {
      final double lat =
          prop.latitud ??
          (_defaultCenter.latitude + (prop.idPropiedad * 0.005));
      final double lng =
          prop.longitud ??
          (_defaultCenter.longitude + (prop.idPropiedad * 0.005));

      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showPropiedadDetalle(context, prop),
          child: const Icon(
            Icons.location_pin,
            size: 40,
            color: Colors.redAccent,
          ),
        ),
      );
    }).toList();

    // Añadir marcador del usuario si está disponible
    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 50,
          height: 50,
          child: const Icon(
            Icons.person_pin_circle,
            size: 50,
            color: Colors.blueAccent,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mapa Premium',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter:
              _userLocation ??
              _defaultCenter, // Centrar en el usuario si existe
          initialZoom: 13.5,
        ),
        children: [
          TileLayer(
            // Capa de OpenStreetMap que no requiere API Key
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.inmobiliaria_mobile',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _getUserLocation(moveMap: true),
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
