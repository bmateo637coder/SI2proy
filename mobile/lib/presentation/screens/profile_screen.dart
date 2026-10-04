import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CircleAvatar(radius: 38, child: Text(user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase())),
          const SizedBox(height: 16),
          Center(child: Text(user.fullName, style: Theme.of(context).textTheme.headlineSmall)),
          Center(child: Text(user.email)),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: user.isActive ? 'Activo' : 'Inactivo'),
              _Chip(label: 'Rol: ${user.idRol}'),
              if (user.idTenant > 0) _Chip(label: 'Empresa: ${user.idTenant}'),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('CI'),
                  trailing: Text(user.ci.isEmpty ? '—' : user.ci),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Teléfono'),
                  trailing: Text(user.telefono.isEmpty ? '—' : user.telefono),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: const Text('Empresa (tenant)'),
                  trailing: Text('${user.idTenant}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Cambiar contraseña'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/profile/cambiar-password'),
            ),
          ),
          const SizedBox(height: 20),
          Text('Permisos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (user.permisos.isEmpty)
            const ListTile(title: Text('Sin permisos asignados'))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.permisos
                  .map((p) => Chip(
                        label: Text(p),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          if (user.roles.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Roles', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...user.roles.map((role) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: Text(role.name),
                    subtitle: Text(role.permissions.isEmpty ? 'Sin permisos' : role.permissions.join(' · ')),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}