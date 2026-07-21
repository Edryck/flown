import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_shell.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/focus/screens/focus_screen.dart';
import '../../features/notes/screens/notes_screen.dart';
import '../../features/projects/screens/projects_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../../features/trash/screens/trash_screen.dart';

/// Rotas do app — mapeiam pros 10 grupos de endpoint do backend real
/// (auth, users/settings, project-types+projects, tasks, notes,
/// sessions/focus, dashboard, search, trash — docs/FLOWN_DOC.md §13), nao
/// pras rotas de demo do protótipo React (esse so serviu de referencia
/// visual, ver docs/prototype/00-overview.md).
///
/// TODO (proxima etapa, feature "auth"): guarda de autenticacao via
/// `redirect`, checando um provider de sessao antes de liberar qualquer
/// rota fora de /login.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            currentPath: state.uri.path,
            onDestinationSelected: (path) => context.go(path),
            child: child,
          );
        },
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/projects', builder: (context, state) => const ProjectsScreen()),
          GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
          GoRoute(path: '/notes', builder: (context, state) => const NotesScreen()),
          GoRoute(path: '/focus', builder: (context, state) => const FocusScreen()),
          GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
          GoRoute(path: '/trash', builder: (context, state) => const TrashScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ],
      ),
    ],
  );
});
