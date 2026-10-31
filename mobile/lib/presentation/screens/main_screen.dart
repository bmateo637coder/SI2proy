import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/company_scope.dart';

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
            const CompanyScope(),
            if (context.watch<AuthProvider>().localSession)
              const MaterialBanner(
                content: Text(
                  'Sesión local: abre Offline para consultar el catálogo descargado.',
                ),
                actions: [SizedBox.shrink()],
              ),
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
