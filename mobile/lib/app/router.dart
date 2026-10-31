import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../presentation/providers/auth_provider.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/profile_screen.dart';
import '../presentation/screens/catalogo_screen.dart';
import '../presentation/screens/main_screen.dart';
import '../presentation/screens/recuperar_password_screen.dart';
import '../presentation/screens/cambiar_password_screen.dart';
import '../presentation/screens/clientes_screen.dart';
import '../presentation/screens/registrar_cliente_screen.dart';
import '../presentation/screens/contratos_screen.dart';
import '../presentation/screens/nuevo_contrato_screen.dart';
import '../presentation/screens/reportes_dinamicos_screen.dart';
import '../presentation/screens/admin/usuarios_screen.dart';
import '../presentation/screens/admin/roles_screen.dart';
import '../presentation/screens/agendar_visita_screen.dart';
import '../presentation/screens/forgot_password_screen.dart';
import '../presentation/screens/map_screen.dart';
import '../presentation/screens/propiedad_detalle_screen.dart';
import '../presentation/screens/offline_screen.dart';
import '../presentation/screens/ia_screen.dart';
import '../presentation/widgets/company_scope.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorCatKey = GlobalKey<NavigatorState>(debugLabel: 'catalogo');
final _shellNavigatorContratosKey = GlobalKey<NavigatorState>(
  debugLabel: 'contratos',
);
final _shellNavigatorClientesKey = GlobalKey<NavigatorState>(
  debugLabel: 'clientes',
);
final _shellNavigatorProfKey = GlobalKey<NavigatorState>(debugLabel: 'perfil');
final _shellNavigatorReportesKey = GlobalKey<NavigatorState>(
  debugLabel: 'reportes',
);

GoRouter createRouter(AuthProvider auth) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/catalogo',
  refreshListenable: auth,
  redirect: (context, state) {
    final location = state.matchedLocation;
    final isPublic = location == '/login' || location == '/recuperar-password';
    if (!auth.isAuthenticated && !isPublic) return '/login';
    if (auth.isAuthenticated && location == '/login') return '/catalogo';
    final user = auth.user;
    if (auth.isAuthenticated && user != null) {
      if (location == '/offline' && user.idRol != 1 && !user.canOperateOffline)
        return '/profile';
      if (location.startsWith('/clientes') && !user.canSeeClientes)
        return '/profile';
      if (location.startsWith('/contratos') && !user.canSeeContratos)
        return '/profile';
      if (location == '/registrar-cliente' && !user.isAdministrator)
        return '/profile';
    }
    if (auth.isAuthenticated &&
        !auth.canWrite &&
        (location == '/contratos/nuevo' || location == '/registrar-cliente'))
      return '/profile';
    return null;
  },
  routes: [
    GoRoute(
      path: '/ia',
      builder: (_, _) => ScopedScreen(builder: (_) => const IaScreen()),
    ),
    GoRoute(
      path: '/offline',
      builder: (_, _) => ScopedScreen(builder: (_) => const OfflineScreen()),
    ),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(
      path: '/recuperar-password',
      builder: (_, _) => const RecuperarPasswordScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellNavigatorCatKey,
          routes: [
            GoRoute(
              path: '/catalogo',
              builder: (context, state) =>
                  ScopedScreen(builder: (_) => const CatalogoScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorContratosKey,
          routes: [
            GoRoute(
              path: '/contratos',
              builder: (context, state) =>
                  ScopedScreen(builder: (_) => const ContratosScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorClientesKey,
          routes: [
            GoRoute(
              path: '/clientes',
              builder: (context, state) =>
                  ScopedScreen(builder: (_) => const ClientesScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorReportesKey,
          routes: [
            GoRoute(
              path: '/reportes',
              builder: (context, state) =>
                  ScopedScreen(builder: (_) => const ReportesDinamicosScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorProfKey,
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/profile/cambiar-password',
              builder: (context, state) => const CambiarPasswordScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/registrar-cliente',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RegistrarClienteScreen(),
    ),
    GoRoute(
      path: '/contratos/nuevo',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NuevoContratoScreen(),
    ),
    GoRoute(
      path: '/usuarios',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          ScopedScreen(builder: (_) => const UsuariosScreen()),
    ),
    GoRoute(
      path: '/roles',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          ScopedScreen(builder: (_) => const RolesScreen()),
    ),

    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/propiedad-detalle',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final prop = state.extra as dynamic;
        return PropiedadDetalleScreen(propiedad: prop);
      },
    ),
    GoRoute(
      path: '/agendar-visita',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final prop = state.extra as dynamic;
        return AgendarVisitaScreen(propiedad: prop);
      },
    ),
    GoRoute(
      path: '/mapa',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MapScreen(),
    ),
  ],
);
