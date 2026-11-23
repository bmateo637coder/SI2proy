import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Excludes missing, non-finite and out-of-projection coordinates.
LatLng? mapCoordinate(Object? latitude, Object? longitude) {
  final lat = double.tryParse('$latitude');
  final lng = double.tryParse('$longitude');
  if (lat == null ||
      lng == null ||
      !lat.isFinite ||
      !lng.isFinite ||
      lat.abs() > 85.05112878 ||
      lng.abs() > 180)
    return null;
  return LatLng(lat, lng);
}

class MapPoint {
  const MapPoint({
    required this.id,
    required this.label,
    required this.point,
    this.intensity = 0,
  });
  final String id, label;
  final LatLng point;
  final double intensity;
}

class RaicesMap extends StatefulWidget {
  const RaicesMap({
    required this.points,
    this.height,
    this.heat = false,
    this.onSelected,
    super.key,
  });
  final List<MapPoint> points;
  final double? height;
  final bool heat;
  final ValueChanged<MapPoint>? onSelected;
  @override
  State<RaicesMap> createState() => _RaicesMapState();
}

class _RaicesMapState extends State<RaicesMap> {
  final controller = MapController();
  bool ready = false;
  String signature(List<MapPoint> points) => points
      .map((p) => '${p.id}:${p.point.latitude}:${p.point.longitude}')
      .join('|');
  @override
  void didUpdateWidget(covariant RaicesMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (signature(oldWidget.points) != signature(widget.points)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) fit();
      });
    }
  }

  void fit() {
    if (!ready || widget.points.isEmpty) return;
    if (widget.points.length == 1) {
      controller.move(widget.points.first.point, 14);
    } else {
      controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(
            widget.points.map((p) => p.point).toList(),
          ),
          padding: const EdgeInsets.fromLTRB(38, 40, 64, 55),
          maxZoom: 14,
        ),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty)
      return SizedBox(
        height: widget.height ?? 260,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_off_outlined, size: 40),
                SizedBox(height: 12),
                Text(
                  'Sin ubicaciones válidas para este filtro.',
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Los inmuebles siguen disponibles en el catálogo.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: widget.points.first.point,
                initialZoom: 13,
                minZoom: 2,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: () {
                  ready = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) fit();
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.inmobiliaria.inmobiliaria_mobile',
                ),
                if (widget.heat)
                  CircleLayer(
                    circles: [
                      for (final p in widget.points)
                        CircleMarker(
                          point: p.point,
                          radius: 350 + 1000 * p.intensity.clamp(0, 1),
                          useRadiusInMeter: true,
                          color: Color.lerp(
                            Colors.amber,
                            Colors.red,
                            p.intensity.clamp(0, 1),
                          )!.withValues(alpha: .28),
                          borderStrokeWidth: 0,
                        ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final p in widget.points)
                      Marker(
                        point: p.point,
                        width: 48,
                        height: 48,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 3,
                          child: IconButton(
                            tooltip: p.label,
                            onPressed: () => widget.onSelected?.call(p),
                            icon: Icon(
                              widget.heat ? Icons.circle : Icons.location_on,
                              color: widget.heat
                                  ? Color.lerp(
                                      Colors.amber,
                                      Colors.red,
                                      p.intensity.clamp(0, 1),
                                    )
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Ver todas las ubicaciones',
                      onPressed: fit,
                      icon: const Icon(Icons.fit_screen),
                    ),
                    for (final step in [1.0, -1.0])
                      IconButton(
                        tooltip: step > 0 ? 'Acercar' : 'Alejar',
                        onPressed: () {
                          if (ready)
                            controller.move(
                              controller.camera.center,
                              (controller.camera.zoom + step).clamp(2, 18),
                            );
                        },
                        icon: Icon(step > 0 ? Icons.add : Icons.remove),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
