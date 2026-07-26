import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/desktop_background_service.dart';
import 'core/services/task_reminder_watcher.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/providers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No-op na Web (ver desktop_background_service_stub.dart) - só faz
  // diferença de verdade no Desktop.
  await initDesktopBackgroundService();
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    // Só observa (e mantém vivo) o watcher de lembretes enquanto há sessão
    // autenticada - desliga sozinho no logout (provider autodispose, ver
    // task_reminder_watcher.dart).
    if (ref.watch(authControllerProvider).valueOrNull != null) {
      ref.watch(taskReminderWatcherProvider);
    }

    return MaterialApp.router(
      title: 'Flown',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
