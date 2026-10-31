import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class CompanyScope extends StatelessWidget {
  const CompanyScope({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isSuperAdmin) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(children: [if (auth.companyError != null) Text(auth.companyError!), Row(
          children: [
            const Icon(Icons.business_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('scope-${auth.selectedTenant}'),
                initialValue:
                    auth.selectedTenant != null &&
                        (auth.selectedTenant == 0 ||
                            auth.companies.any(
                              (c) => c['id_tenant'] == auth.selectedTenant,
                            ))
                    ? auth.selectedTenant
                    : 0,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Inmobiliaria activa',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: 0,
                    child: Text('Todas las inmobiliarias'),
                  ),
                  ...auth.companies.map(
                    (c) => DropdownMenuItem(
                      value: (c['id_tenant'] as num).toInt(),
                      child: Text(
                        c['nombre'].toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (id) {
                  if (id != null) auth.selectTenant(id);
                },
              ),
            ),
            IconButton(
              tooltip: 'Actualizar inmobiliarias',
              onPressed: auth.loadCompanies,
              icon: const Icon(Icons.refresh),
            ),
          ],
        )]),
      ),
    );
  }
}

/// Desecha formularios y resultados al cambiar de cuenta o inmobiliaria.
class ScopedScreen extends StatelessWidget {
  const ScopedScreen({required this.builder, super.key});
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ValueKey(context.watch<AuthProvider>().scopeKey),
    child: builder(context),
  );
}
