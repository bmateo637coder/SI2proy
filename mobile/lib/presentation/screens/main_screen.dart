import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final showContratos = user?.canSeeContratos ?? false;
    final showClientes = user?.canSeeClientes ?? false;

    // Router branch order (main_screen must mirror router.dart branches):
    // 0 catálogo, 1 contratos (condicional), 2 clientes (condicional), 3 perfil
    final destinationBranches = <int>[
      0,
      if (showContratos) 1,
      if (showClientes) 2,
      3,
    ];

    final currentBranch = navigationShell.currentIndex;
    final destinationIndex = destinationBranches.indexOf(currentBranch);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: destinationIndex >= 0 ? destinationIndex : 0,
        onDestinationSelected: (index) {
          final branch = destinationBranches[index];
          navigationShell.goBranch(
            branch,
            initialLocation: branch == navigationShell.currentIndex,
          );
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Catálogo',
          ),
          if (showContratos)
            const NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Contratos',
            ),
          if (showClientes)
            const NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Clientes',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}