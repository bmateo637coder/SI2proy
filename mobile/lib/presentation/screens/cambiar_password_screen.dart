import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

final _passwordPattern = RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]+$');

class CambiarPasswordScreen extends StatefulWidget {
  const CambiarPasswordScreen({super.key});

  @override
  State<CambiarPasswordScreen> createState() => _CambiarPasswordScreenState();
}

class _CambiarPasswordScreenState extends State<CambiarPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final provider = context.read<AuthProvider>();
    final success = await provider.changePassword(_passwordController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Contraseña actualizada correctamente.' : provider.errorMessage ?? 'No se pudo cambiar la contraseña.'),
      ),
    );
    if (success) context.go('/profile');
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
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
                    const Icon(Icons.password, size: 58),
                    const SizedBox(height: 18),
                    Text(
                      'Define una nueva contraseña',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        helperText: 'Mínimo 8 caracteres, una mayúscula, un número y un símbolo (@\$!%*?&)',
                        suffixIcon: IconButton(
                          tooltip: 'Mostrar contraseña',
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 8 || !_passwordPattern.hasMatch(value)) {
                          return 'Debe tener al menos 8 caracteres, una mayúscula, un número y un símbolo (@\$!%*?&)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirmar nueva contraseña',
                        suffixIcon: IconButton(
                          tooltip: 'Mostrar contraseña',
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                      validator: (value) => value == _passwordController.text ? null : 'Las contraseñas no coinciden',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Guardar nueva contraseña'),
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