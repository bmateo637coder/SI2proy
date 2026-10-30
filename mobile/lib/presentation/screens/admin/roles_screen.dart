import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/config/api_constants.dart';
import '../../../data/network/auth_interceptor.dart';
import '../../../data/services/secure_storage_service.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});
  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  final _storage = SecureStorageService();
  List<dynamic> _items = [];
  bool _loading = true;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _dio.interceptors.add(AuthInterceptor(_storage, () async {}));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _dio.get('/roles');
      setState(() => _items = r.data as List<dynamic>? ?? []);
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Roles')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final r = _items[i] as Map<String,dynamic>;
          return ListTile(title: Text(r['nombre']?.toString() ?? ''), subtitle: Text('Permisos: ${(r['permisos'] as List<dynamic>? ?? []).length}'));
        },
      ),
    );
  }
}
