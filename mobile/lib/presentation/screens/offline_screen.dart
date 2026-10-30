import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/offline_service.dart';
import '../providers/auth_provider.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});
  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> snapshot = {};
  List<Map<String, dynamic>> operations = [];
  String message = '';
  bool busy = false;
  int? clientId;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reload();
      sync();
    });
    timer = Timer.periodic(const Duration(seconds: 30), (_) => sync());
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) sync();
  }

  Future<void> reload() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      final service = context.read<OfflineService>();
      final data = await service.readSnapshot(user);
      final rows = await service.operations(user);
      if (mounted) {
        setState(() {
          snapshot = data;
          operations = rows;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'No se pudo abrir SQLite en este dispositivo. Usa Android o iOS.',
        );
      }
    }
  }

  Future<void> action(Future<void> Function(OfflineService) work) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await work(context.read<OfflineService>());
      await reload();
    } catch (e) {
      if (mounted) setState(() => message = 'No se completó la operación: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sync() async {
    if (!mounted || busy) return;
    final user = context.read<AuthProvider>().user;
    if (user != null && user.canOperateOffline) {
      await action((s) => s.synchronize(user));
    }
  }

  Future<void> queue(Map<String, dynamic> prop, String type) async {
    final user = context.read<AuthProvider>().user;
    if (user == null || clientId == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          type == 'reserva'
              ? 'Registrar reserva local'
              : 'Registrar venta en efectivo',
        ),
        content: Text(
          '${prop['titulo']} · USD ${prop['precio']}\nQuedará pendiente hasta que el servidor confirme precio y disponibilidad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Guardar en dispositivo'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await action((s) async {
        await s.queue(user, prop, clientId!, type);
        if (mounted) {
          setState(
            () => message = 'Guardada localmente. Pendiente de confirmación.',
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null || !user.canOperateOffline) {
      return const Scaffold(
        body: Center(
          child: Text('Acceso reservado a administradores y agentes.'),
        ),
      );
    }
    final properties = (snapshot['propiedades'] as List?) ?? [];
    final clients = (snapshot['clientes'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Operaciones sin conexión')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'La información local puede estar desactualizada. Una venta en efectivo requiere confirmación posterior del servidor.',
          ),
          Text(
            'Última descarga: ${snapshot['descargado_en'] ?? 'Sin catálogo descargado'}',
          ),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: busy ? null : () => action((s) => s.download(user)),
                child: const Text('Descargar catálogo'),
              ),
              OutlinedButton(
                onPressed: busy ? null : sync,
                child: const Text('Sincronizar'),
              ),
            ],
          ),
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: clientId,
            decoration: const InputDecoration(labelText: 'Cliente'),
            items: clients
                .map(
                  (c) => DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text(c['name'] as String),
                  ),
                )
                .toList(),
            onChanged: busy ? null : (v) => setState(() => clientId = v),
          ),
          const SizedBox(height: 16),
          ...properties.map(
            (p) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['titulo'] as String,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${p['direccion']}\nUSD ${p['precio']} · ${p['tipo_operacion']} · ${p['estado']}',
                    ),
                    Text(
                      'Sucursal #${p['id_sucursal']} · Versión ${p['version']}',
                    ),
                    for (final c in (p['caracteristicas'] as List?) ?? [])
                      Text('${c['nombre']}: ${c['valor']}'),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed:
                              busy ||
                                  clientId == null ||
                                  p['estado'] != 'Disponible'
                              ? null
                              : () =>
                                    queue(p as Map<String, dynamic>, 'reserva'),
                          child: const Text('Reservar'),
                        ),
                        TextButton(
                          onPressed:
                              busy ||
                                  clientId == null ||
                                  p['estado'] != 'Disponible' ||
                                  p['tipo_operacion'] != 'Venta'
                              ? null
                              : () => queue(
                                  p as Map<String, dynamic>,
                                  'venta_contado',
                                ),
                          child: const Text('Venta en efectivo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Historial local',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (operations.isEmpty)
            const Text('Sin operaciones para esta cuenta.'),
          ...operations.map((op) {
            final data =
                jsonDecode(op['payload'] as String) as Map<String, dynamic>;
            return Card(
              child: ListTile(
                trailing:
                    data['tipo'] == 'reserva' && op['status'] == 'confirmada'
                    ? TextButton(
                        onPressed: busy
                            ? null
                            : () => action(
                                (s) => s.cancel(user, op['uuid'] as String),
                              ),
                        child: const Text('Cancelar'),
                      )
                    : null,
                title: Text(
                  '${data['tipo']} · #${op['property_id']} · ${op['status']}',
                ),
                subtitle: Text(
                  'USD ${data['total']}\n${op['uuid']}\n${op['message'] ?? 'Guardada sin confirmación'}',
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
