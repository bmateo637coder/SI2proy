import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/services/replica_store.dart';
import '../../data/services/replica_controller.dart';
import '../providers/auth_provider.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});
  static const operationNames = {
    'cliente.crear': 'Registrar cliente',
    'contrato.crear': 'Nuevo contrato',
    'pago.crear': 'Registrar pago',
    'contrato.eliminar': 'Eliminar contrato',
    'reporte.guardar': 'Guardar reporte',
    'propiedad.crear': 'Nueva propiedad',
    'propiedad.actualizar': 'Editar propiedad',
    'propiedad.estado': 'Cambiar estado',
    'propiedad.eliminar': 'Eliminar propiedad',
  };
  @override
  Widget build(BuildContext context) {
    final store = context.watch<ReplicaStore>();
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronización'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/catalogo'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            store.message ?? 'La descarga y sincronización se ejecutan automáticamente al abrir la app y mientras la usas.',
          ),
          const SizedBox(height: 12),
          Text(
            'Última copia completa: ${store.lastDownload ?? "todavía no disponible"}',
          ),
          Text(
            '${store.pending} pendientes · ${store.conflicts} necesitan revisión',
          ),
          if (store.imagesStatus != null) Text(store.imagesStatus!),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: store.syncing || store.downloading
                ? null
                : () => context.read<ReplicaController>().refresh(force: true),
            icon: const Icon(Icons.sync),
            label: const Text('Sincronizar ahora'),
          ),
          if (auth.needsOnlineLogin)
            OutlinedButton(
              onPressed: () => context.go('/validar-sesion'),
              child: const Text('Validar sesión para sincronizar'),
            ),
          const SizedBox(height: 12),
          const Text(
            'Los cambios pendientes se guardan en este teléfono. Si otra persona modificó el mismo registro, se conserva el dato del servidor y se presenta aquí el conflicto. Revisa ambas versiones antes de volver a registrar el cambio.',
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: store.operations(),
            builder: (context, snapshot) => Column(
              children: [
                for (final row in snapshot.data ?? <Map<String, dynamic>>[])
                  _operation(context, store, row),
                if (snapshot.hasData && snapshot.data!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hay cambios locales registrados.'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/offline'),
            child: const Text('Reservas y ventas en efectivo'),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: store.legacyOperations?.call(),
            builder: (context, snapshot) => Column(
              children: [
                for (final row in snapshot.data ?? <Map<String, dynamic>>[])
                  Card(
                    child: ExpansionTile(
                      title: Text(
                        '${jsonDecode(row['payload'] as String)['tipo']} · inmobiliaria ${jsonDecode(row['payload'] as String)['id_tenant']}',
                      ),
                      subtitle: Text(
                        '${row['status']}${row['cancel_requested'] == 1 ? ' · cancelación pendiente' : ''}',
                      ),
                      children: [
                        ListTile(
                          title: Text(
                            '${row['message'] ?? "Guardada en el dispositivo"}',
                          ),
                          subtitle: SelectableText(
                            const JsonEncoder.withIndent('  ')
                                .convert(jsonDecode(row['payload'] as String)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _operation(
    BuildContext context,
    ReplicaStore store,
    Map<String, dynamic> row,
  ) {
    final body = jsonDecode(row['payload'] as String) as Map;
    final result = row['result'] == null
        ? null
        : jsonDecode(row['result'] as String);
    final problem = ['conflicto', 'rechazada'].contains(row['state']);
    return Card(
      child: ExpansionTile(
        leading: Icon(
          problem
              ? Icons.warning_amber
              : row['state'] == 'confirmada'
              ? Icons.check_circle_outline
              : Icons.schedule,
        ),
        title: Text(
          '${operationNames[body['tipo']] ?? body['tipo']} · inmobiliaria ${body['id_tenant']}',
        ),
        subtitle: Text('${row['state']}'),
        children: [
          ListTile(
            title: const Text('Tu cambio'),
            subtitle: SelectableText(
              const JsonEncoder.withIndent('  ').convert(body['datos']),
            ),
          ),
          if (result != null)
            ListTile(
              title: Text(
                problem
                    ? 'Motivo y versión actual del servidor'
                    : 'Confirmación del servidor',
              ),
              subtitle: SelectableText(
                const JsonEncoder.withIndent('  ').convert(result),
              ),
            ),
          if (problem || row['state'] == 'pendiente')
            TextButton(
              onPressed: () async {
                final approved = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Descartar propuesta local'),
                    content: const Text(
                      'Se conservarán los datos del servidor. Esta propuesta ya no se enviará. Los cambios que dependan de ella también se descartarán.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Volver'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Descartar'),
                      ),
                    ],
                  ),
                );
                if (approved == true)
                  await store.discard(row['uuid'] as String);
              },
              child: const Text('Descartar propuesta'),
            ),
        ],
      ),
    );
  }
}
