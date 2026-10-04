import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/clientes_provider.dart';

class RegistrarClienteScreen extends StatefulWidget {
  const RegistrarClienteScreen({super.key});

  @override
  State<RegistrarClienteScreen> createState() => _RegistrarClienteScreenState();
}

class _RegistrarClienteScreenState extends State<RegistrarClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ciController = TextEditingController();

  @override
  void dispose() {
    _ciController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final provider = context.read<ClientesProvider>();
    final success = await provider.createCliente(_ciController.text);
    if (!mounted) return;
    if (success) {
      context.pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el cliente: ${provider.errorMessage}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreating = context.watch<ClientesProvider>().isCreating;
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Cliente')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.person_add_alt_1, size: 58),
                    const SizedBox(height: 18),
                    Text(
                      'Asignar rol de cliente',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ingresa el CI de un usuario ya existente en la empresa para darlo de alta como cliente.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _ciController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(labelText: 'CI del usuario'),
                      validator: (value) => value != null && value.trim().isNotEmpty
                          ? null
                          : 'Introduce el CI del usuario',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: isCreating ? null : _submit,
                      child: isCreating
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Registrar cliente'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}