import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/clientes_provider.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientesProvider>().fetchClientes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClientesProvider>();
    final canRegister = context.watch<AuthProvider>().user?.isAdministrator ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Clientes'),
        centerTitle: true,
      ),
      floatingActionButton: canRegister
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await context.push<bool>('/registrar-cliente');
                if (!mounted) return;
                if (created == true) {
                  this.context.read<ClientesProvider>().fetchClientes();
                }
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Registrar'),
            )
          : null,
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
                        onPressed: () => provider.fetchClientes(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : provider.clientes.isEmpty
                  ? const Center(child: Text('No hay clientes registrados aún.'))
                  : RefreshIndicator(
                      onRefresh: provider.fetchClientes,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.clientes.length,
                        itemBuilder: (context, index) {
                          final cliente = provider.clientes[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                child: Text(cliente.nombre.isEmpty ? '?' : cliente.nombre[0].toUpperCase()),
                              ),
                              title: Text(
                                cliente.nombre,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  if (cliente.correo.isNotEmpty) Text(cliente.correo),
                                  if (cliente.telefono.isNotEmpty) Text(cliente.telefono),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'CI ${cliente.ciUsuario}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cliente #${cliente.idCliente}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}