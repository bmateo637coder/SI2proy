import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../../../data/services/api_error.dart';
import '../../widgets/company_scope.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});
  @override
  State<RolesScreen> createState() => _ScreenState();
}

class _ScreenState extends State<RolesScreen> {
  List<dynamic> items = [];
  bool loading = true;
  String message = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      message = '';
    });
    try {
      final response = await context.read<Dio>().get('/roles');
      if (mounted) setState(() => items = response.data as List);
    } catch (e) {
      if (mounted) setState(() => message = apiError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Roles y permisos'),
      actions: [
        IconButton(
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        const CompanyScope(),
        if (loading) const LinearProgressIndicator(),
        if (message.isNotEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text(message)),
        if (!loading && message.isEmpty && items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Sin registros para esta selección.'),
          ),
        Expanded(
          child: ListView(
            children: items
                .map(
                  (u) => ListTile(
                    title: Text('${u['nombre'] ?? u['name'] ?? ''}'),
                    subtitle: Text(
                      'Permisos: ${u['permisos'] ?? u['permissions'] ?? []}',
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );
}
