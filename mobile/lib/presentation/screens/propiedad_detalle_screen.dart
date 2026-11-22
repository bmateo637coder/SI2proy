import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/api_constants.dart';
import '../../data/models/propiedad_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/property_image.dart';
import '../../data/services/sprint4_service.dart';

class PropiedadDetalleScreen extends StatelessWidget {
  const PropiedadDetalleScreen({super.key, required this.propiedad});
  final PropiedadModel propiedad;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle de propiedad')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final image in propiedad.imagenes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PropertyImage(
              Uri.parse(ApiConstants.baseUrl).resolve(image.url).toString(),
              height: 230,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.image_not_supported, size: 64),
            ),
          ),
        Text(
          propiedad.inmobiliaria,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          propiedad.titulo,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(propiedad.direccion),
        Text(
          'USD ${propiedad.precio.toStringAsFixed(2)} · ${propiedad.tipoOperacion} · ${propiedad.estado}',
        ),
        FilledButton.tonalIcon(onPressed: () async {
          try {
            final result=await context.read<Sprint4Service>().mutate('POST','/api/favoritos/${propiedad.idPropiedad}');
            if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result['pendiente']==true?'Favorito guardado; pendiente de sincronización.':'Favorito guardado.')));
          } catch(_) { if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No se pudo guardar. Revisa Sincronización de servicios.'))); }
        }, icon:const Icon(Icons.favorite_outline),label:const Text('Guardar favorito')),
        if(propiedad.estado=='Disponible')FilledButton.icon(onPressed:()=>context.push('/agendar-visita',extra:propiedad),icon:const Icon(Icons.event),label:const Text('Agendar visita')),
        const Divider(height: 32),
        SelectableText(
          propiedad.descripcion.isEmpty
              ? 'Sin descripción registrada.'
              : propiedad.descripcion,
        ),
        ...propiedad.caracteristicas.map(
          (c) => ListTile(
            title: Text('${c['nombre']}'),
            trailing: Text('${c['valor']}'),
          ),
        ),
        if (context.watch<AuthProvider>().user?.idRol == 1 ||
            context.watch<AuthProvider>().operationUser?.canOperateOffline ==
                true)
          OutlinedButton.icon(
            onPressed: () => context.push('/offline'),
            icon: const Icon(Icons.offline_bolt),
            label: const Text('Gestionar reservas y ventas en Offline'),
          ),
      ],
    ),
  );
}
