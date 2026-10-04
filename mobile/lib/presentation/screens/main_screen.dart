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
    final showClientes = context.watch<AuthProvider>().user?.canSeeClientes ?? false;
    final branchIndex = navigationShell.currentIndex;
    final destinationIndex = showClientes ? branchIndex : (branchIndex > 0 ? branchIndex - 1 : 0);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: destinationIndex,
        onDestinationSelected: (index) {
          final branch = showClientes ? index : (index >= 1 ? index + 1 : 0);
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