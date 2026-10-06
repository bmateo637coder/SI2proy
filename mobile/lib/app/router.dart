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

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorCatKey = GlobalKey<NavigatorState>(debugLabel: 'catalogo');
final _shellNavigatorContratosKey = GlobalKey<NavigatorState>(debugLabel: 'contratos');
final _shellNavigatorClientesKey = GlobalKey<NavigatorState>(debugLabel: 'clientes');
final _shellNavigatorProfKey = GlobalKey<NavigatorState>(debugLabel: 'perfil');

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
          if (location.startsWith('/clientes') && !user.canSeeClientes) return '/perfil';
          if (location.startsWith('/contratos') && !user.canSeeContratos) return '/perfil';
          if (location == '/registrar-cliente' && !user.isAdministrator) return '/perfil';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => const LoginScreen(),
        ),
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
                  builder: (context, state) => const CatalogoScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _shellNavigatorContratosKey,
              routes: [
                GoRoute(
                  path: '/contratos',
                  builder: (context, state) => const ContratosScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _shellNavigatorClientesKey,
              routes: [
                GoRoute(
                  path: '/clientes',
                  builder: (context, state) => const ClientesScreen(),
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
      ],
    );