import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/config/api_constants.dart';
import '../../../data/network/auth_interceptor.dart';
import '../../../data/services/secure_storage_service.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});
  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
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
      final r = await _dio.get('/usuarios');
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
      appBar: AppBar(title: const Text('Gestión de Usuarios')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final u = _items[i] as Map<String,dynamic>;
          return ListTile(
            title: Text(u['nombre']?.toString() ?? ''),
            subtitle: Text('${u['correo'] ?? ''} • Rol: ${u['id_rol']}'),
            trailing: Text(u['is_active']==true?'Activo':'Inactivo'),
          );
        },
      ),
    );
  }
}
