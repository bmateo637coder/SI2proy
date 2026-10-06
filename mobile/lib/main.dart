import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/router.dart';
import 'core/config/api_constants.dart';
import 'data/network/auth_interceptor.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/clientes_repository.dart';
import 'data/repositories/contratos_repository.dart';
import 'data/repositories/propiedades_repository.dart';
import 'data/services/auth_service.dart';
import 'data/services/clientes_service.dart';
import 'data/services/contratos_service.dart';
import 'data/services/propiedades_service.dart';
import 'data/services/secure_storage_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/clientes_provider.dart';
import 'presentation/providers/contratos_provider.dart';
import 'presentation/providers/propiedades_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = SecureStorageService();
  late AuthProvider auth;
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));
  final authService = AuthService(dio);
  final propiedadesService = PropiedadesService(dio);
  final clientesService = ClientesService(dio);
  final contratosService = ContratosService(dio);
  auth = AuthProvider(AuthRepository(authService), storage);
  final propiedadesProvider = PropiedadesProvider(PropiedadesRepository(propiedadesService));
  final clientesProvider = ClientesProvider(ClientesRepository(clientesService));
  final contratosProvider = ContratosProvider(ContratosRepository(contratosService));
  dio.interceptors.add(AuthInterceptor(storage, auth.signOut));
  await auth.restoreSession();
  runApp(InmobiliariaApp(
    auth: auth,
    propiedadesProvider: propiedadesProvider,
    clientesProvider: clientesProvider,
    contratosProvider: contratosProvider,
  ));
}

class InmobiliariaApp extends StatelessWidget {
  const InmobiliariaApp({
    required this.auth,
    required this.propiedadesProvider,
    required this.clientesProvider,
    required this.contratosProvider,
    super.key,
  });

  final AuthProvider auth;
  final PropiedadesProvider propiedadesProvider;
  final ClientesProvider clientesProvider;
  final ContratosProvider contratosProvider;

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: propiedadesProvider),
          ChangeNotifierProvider.value(value: clientesProvider),
          ChangeNotifierProvider.value(value: contratosProvider),
        ],
        child: MaterialApp.router(
          title: 'Inmobiliaria',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff0e7490),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
            ),
          ),
          routerConfig: createRouter(auth),
        ),
      );
}