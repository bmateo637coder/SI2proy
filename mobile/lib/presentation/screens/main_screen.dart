import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/company_scope.dart';
import 'workspace_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final showContratos = user?.canSeeContratos ?? false;
    final showClientes = user?.canSeeClientes ?? false;
    final showReportes = user?.canSeeReportes ?? false;

    final destinationBranches = <int>[];
    destinationBranches.add(0);
    if (showContratos) destinationBranches.add(1);
    if (showClientes) destinationBranches.add(2);
    if (showReportes) destinationBranches.add(3);
    destinationBranches.add(4);

    final currentBranch = navigationShell.currentIndex;
    final destinationIndex = destinationBranches.indexOf(currentBranch);

    final destinations = <NavigationDestination>[];
    destinations.add(
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Catálogo',
      ),
    );
    if (showContratos) {
      destinations.add(
        const NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'Contratos',
        ),
      );
    }
    if (showClientes) {
      destinations.add(
        const NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Clientes',
        ),
      );
    }
    if (showReportes) {
      destinations.add(
        const NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: 'Reportes',
        ),
      );
    }
    destinations.add(
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Perfil',
      ),
    );

    return Scaffold(
      drawer: const Drawer(width: 360, child: WorkspaceScreen(drawer: true)),
      floatingActionButton:
          (user?.idRol == 1 || user?.canOperateOffline == true)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/offline'),
              icon: const Icon(Icons.offline_bolt),
              label: const Text('Offline'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Builder(
                    builder: (c) => IconButton(
                      tooltip: 'Todas las funciones',
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(c).openDrawer(),
                    ),
                  ),
                  Text(
                    'RAÍCES',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.push('/inicio'),
                    icon: const Icon(Icons.grid_view_outlined),
                    label: const Text('Todo'),
                  ),
                  IconButton(
                    tooltip: 'Notificaciones',
                    onPressed: () =>
                        context.push('/servicios?seccion=Notificaciones'),
                    icon: const Icon(Icons.notifications_none),
                  ),
                ],
              ),
            ),
            const CompanyScope(),
            Expanded(child: navigationShell),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: destinationIndex >= 0 ? destinationIndex : 0,
        onDestinationSelected: (index) {
          final branch = destinationBranches[index];
          navigationShell.goBranch(
            branch,
            initialLocation: branch == navigationShell.currentIndex,
          );
        },
        destinations: destinations,
      ),
    );
  }
}
