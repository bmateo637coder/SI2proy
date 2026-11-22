import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/company_scope.dart';
import '../widgets/workspace_modules.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, this.drawer = false});
  final bool drawer;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final modules = workspaceModules(auth.user)
        .where(
          (m) =>
              workspaceSearch('${m.title} ${m.subtitle} ${m.group}')
                  .contains(workspaceSearch(query)),
        )
        .toList();
    final groups = modules.map((m) => m.group).toSet();
    final search = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        key: const ValueKey('workspace-search'),
        onChanged: (value) => setState(() => query = value),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Buscar una función…',
        ),
      ),
    );
    final content = ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (query.trim().isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff123e4b), Color(0xff0e7490)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RAÍCES',
                  style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.drawer
                      ? 'Todas las funciones'
                      : 'Tu inmobiliaria, a la mano',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  auth.scopeLabel,
                  style: const TextStyle(color: Colors.white),
                ),
                if (auth.allTenants)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Consulta todas las empresas. Para registrar cambios, elige una inmobiliaria.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (modules.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No encontramos funciones con ese nombre.'),
          ),
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 0, 10),
            child: Text(
              group,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...modules
              .where((m) => m.group == group)
              .map(
                (m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: Icon(
                        m.icon,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      m.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(m.subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (widget.drawer) Navigator.pop(context);
                      if ([
                        '/catalogo',
                        '/contratos',
                        '/clientes',
                        '/reportes',
                        '/profile',
                      ].contains(m.path)) {
                        context.go(m.path);
                      } else {
                        context.push(m.path);
                      }
                    },
                  ),
                ),
              ),
        ],
      ],
    );
    if (widget.drawer) {
      return SafeArea(
        child: Column(
          children: [
            search,
            Expanded(child: content),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Centro de trabajo')),
      body: Column(
        children: [
          const CompanyScope(),
          search,
          Expanded(child: content),
        ],
      ),
    );
  }
}
