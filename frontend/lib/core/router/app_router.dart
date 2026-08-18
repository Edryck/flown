import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_shell.dart';
import '../widgets/splash_screen.dart';
import '../../features/auth/providers/auth_controller.dart';
import '../../features/auth/screens/google_callback_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/focus/screens/focus_screen.dart';
import '../../features/notes/screens/notes_screen.dart';
import '../../features/projects/screens/projects_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/statistics/screens/statistics_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../../features/trash/screens/trash_screen.dart';

/// Notifica o `GoRouter` (via `refreshListenable`) toda vez que o estado de
/// auth muda, sem recriar a instancia do router — recriar o GoRouter a cada
/// mudanca de estado perderia o historico de navegacao interno dele.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

/// Rotas do app — mapeiam pros 10 grupos de endpoint do backend real
/// (auth, users/settings, project-types+projects, tasks, notes,
/// sessions/focus, dashboard, search, trash — docs/FLOWN_DOC.md §13), nao
/// pras rotas de demo do protótipo React (esse so serviu de referencia
/// visual, ver docs/prototype/00-overview.md).
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isLoggingIn = location == '/login';
      // Rota so de Web pra onde o backend redireciona depois do login no
      // Google (ver google_callback_screen.dart) — tambem publica, senao o
      // redirect abaixo empurraria pro /login antes da troca de handoff
      // rodar.
      final isGoogleCallback = location == '/auth/google/callback';
      // /login e /splash sao publicas — enquanto isLoading, um clique em
      // "Entrar"/"Criar conta" tambem deixa o estado em loading (log da
      // tela), e isso NAO pode empurrar o usuario pra /splash: perderia o
      // que foi digitado no formulario. So a checagem inicial de sessao
      // (usuario ainda em rota protegida/raiz) deve mostrar a splash.
      final isPublicRoute = isSplash || isLoggingIn || isGoogleCallback;

      if (authState.isLoading) {
        return isPublicRoute ? null : '/splash';
      }

      final isAuthenticated = authState.valueOrNull != null;

      if (!isAuthenticated) {
        return isLoggingIn ? null : '/login';
      }

      if (isPublicRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/auth/google/callback',
        builder: (context, state) => GoogleCallbackScreen(
          handoff: state.uri.queryParameters['handoff'],
          error: state.uri.queryParameters['error'],
        ),
      ),
      // Fora do ShellRoute de propósito: igual ao protótipo (routes.tsx),
      // /focus é a única rota sem TopNavBar/FAB — tela cheia imersiva.
      GoRoute(path: '/focus', builder: (context, state) => const FocusScreen()),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            currentPath: state.uri.path,
            onDestinationSelected: (path) => context.go(path),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          // Sem rotas '/projects/new', '/tasks/new' nem '/tasks/:id/edit' de
          // propósito — criar/editar projeto e tarefa agora são modais
          // (`showProjectFormDialog`/`showTaskFormDialog`), não telas.
          GoRoute(
            path: '/projects',
            builder: (context, state) => const ProjectsScreen(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => TasksScreen(
              initialOnlyOverdue: state.uri.queryParameters['overdue'] == 'true',
            ),
          ),
          GoRoute(
            path: '/notes',
            builder: (context, state) => const NotesScreen(),
          ),
          GoRoute(
            path: '/statistics',
            builder: (context, state) => const StatisticsScreen(),
          ),
          GoRoute(
            path: '/trash',
            builder: (context, state) => const TrashScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
