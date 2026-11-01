import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/replica_store.dart';
import '../providers/auth_provider.dart';

class SyncStatus extends StatelessWidget {
  const SyncStatus({required this.onOpen, super.key});
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) return const SizedBox.shrink();
    final store = context.watch<ReplicaStore>();
    final status = store.downloading
        ? 'Descargando datos…'
        : store.syncing
        ? 'Sincronizando…'
        : !store.online
        ? 'Sin conexión · copia local'
        : store.lastDownload == null
        ? 'Preparando uso sin Internet…'
        : 'Copia local lista';
    final color = store.conflicts > 0
        ? Colors.orange.shade100
        : !store.online
        ? Colors.amber.shade100
        : Theme.of(context).colorScheme.surfaceContainerLow;
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  !store.online
                      ? Icons.cloud_off
                      : store.conflicts > 0
                      ? Icons.sync_problem
                      : Icons.cloud_done_outlined,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$status${store.pending > 0 ? ' · ${store.pending} pendientes' : ''}${store.conflicts > 0 ? ' · ${store.conflicts} conflictos' : ''}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
