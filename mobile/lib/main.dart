import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';

import 'data/services/replica_store.dart';
import 'data/services/replica_controller.dart';
import 'presentation/widgets/sync_status.dart';

import 'app/router.dart';

import 'package:go_router/go_router.dart';

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
import 'data/services/offline_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/clientes_provider.dart';
import 'presentation/providers/contratos_provider.dart';
import 'presentation/providers/propiedades_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterCryptography.enable();
  final storage = SecureStorageService();
  late AuthProvider auth;
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 90),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  final authService = AuthService(dio);
  final propiedadesService = PropiedadesService(dio);
  final clientesService = ClientesService(dio);
  final contratosService = ContratosService(dio);
  auth = AuthProvider(AuthRepository(authService), storage);
  final propiedadesProvider = PropiedadesProvider(
    PropiedadesRepository(propiedadesService),
  );
  final clientesProvider = ClientesProvider(
    ClientesRepository(clientesService),
  );
  final contratosProvider = ContratosProvider(
    ContratosRepository(contratosService),
  );
  dio.interceptors.add(AuthInterceptor(storage, auth.sessionExpired));
  final replica = ReplicaStore(user: () => auth.user);
  final interceptor = ReplicaInterceptor(replica, auth);
  dio.interceptors.add(interceptor);
  auth.onScopeChanged = () {
    propiedadesProvider.reset();
    clientesProvider.reset();
    contratosProvider.reset();
  };
  await auth.restoreSession();
  replica.online = !auth.localSession;
  runApp(
    InmobiliariaApp(
      dio: dio,
      auth: auth,
      propiedadesProvider: propiedadesProvider,
      clientesProvider: clientesProvider,
      contratosProvider: contratosProvider,
      offlineService: OfflineService(dio),
      replica: replica,
      replicaInterceptor: interceptor,
    ),
  );
}

class InmobiliariaApp extends StatefulWidget {
  const InmobiliariaApp({
    required this.dio,
    required this.auth,
    required this.propiedadesProvider,
    required this.clientesProvider,
    required this.contratosProvider,
    required this.offlineService,
    this.replica,
    this.replicaInterceptor,
    super.key,
  });

  final Dio dio;
  final AuthProvider auth;
  final PropiedadesProvider propiedadesProvider;
  final ClientesProvider clientesProvider;
  final ContratosProvider contratosProvider;
  final OfflineService offlineService;
  final ReplicaStore? replica;
  final ReplicaInterceptor? replicaInterceptor;

  @override
  State<InmobiliariaApp> createState() => _InmobiliariaAppState();
}

class _InmobiliariaAppState extends State<InmobiliariaApp> {
  late final GoRouter router = createRouter(widget.auth);
  ReplicaController? controller;
  void refreshVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.auth.isAuthenticated) return;
      final location = router.routeInformationProvider.value.uri.path;
      if (location == '/catalogo')
        widget.propiedadesProvider.fetchPropiedades();
      if (location == '/clientes') widget.clientesProvider.fetchClientes();
      if (location == '/contratos') widget.contratosProvider.fetchContratos();
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.replica case final ReplicaStore store) {
      router.routeInformationProvider.addListener(refreshVisible);
      controller = ReplicaController(
        widget.dio,
        widget.auth,
        store,
        widget.offlineService,
      );
      widget.replicaInterceptor?.onQueued = () =>
          controller?.refresh(force: true);
      store.onDataChanged = refreshVisible;
      controller!.start();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    if (widget.replica != null)
      router.routeInformationProvider.removeListener(refreshVisible);
    widget.replica?.onDataChanged = null;
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider.value(value: widget.dio),
      ChangeNotifierProvider.value(value: widget.auth),
      ChangeNotifierProvider.value(value: widget.propiedadesProvider),
      ChangeNotifierProvider.value(value: widget.clientesProvider),
      ChangeNotifierProvider.value(value: widget.contratosProvider),
      Provider.value(value: widget.offlineService),
      if (widget.replica != null)
        ChangeNotifierProvider.value(value: widget.replica!),
      if (controller != null) Provider.value(value: controller!),
    ],
    child: MaterialApp.router(
      title: 'Raíces',
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
      routerConfig: router,
      builder: (context, child) => widget.replica == null
          ? child!
          : Column(
              children: [
                SyncStatus(onOpen: () => router.go('/sincronizacion')),
                Expanded(child: child!),
              ],
            ),
    ),
  );
}
