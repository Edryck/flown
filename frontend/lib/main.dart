import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/desktop_background_service.dart';
import 'core/services/task_reminder_watcher.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/theme/theme_preset_provider.dart';
import 'core/theme/theme_presets.dart';
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
    // Presets diferentes de `flown` (ver theme_presets.dart) são uma
    // identidade fixa - não seguem o toggle claro/escuro nem o sistema, por
    // isso usam o mesmo ThemeData pra `theme`/`darkTheme` e travam o
    // `themeMode`, ignorando `appThemeModeProvider` enquanto ativos.
    final preset =
        ref.watch(appThemePresetProvider).valueOrNull ?? ThemePreset.flown;
    final fixedTheme = preset.fixedThemeData;

    // Só observa (e mantém vivo) o watcher de lembretes enquanto há sessão
    // autenticada - desliga sozinho no logout (provider autodispose, ver
    // task_reminder_watcher.dart).
    if (ref.watch(authControllerProvider).valueOrNull != null) {
      ref.watch(taskReminderWatcherProvider);
    }

    return MaterialApp.router(
      title: 'Flown',
      debugShowCheckedModeBanner: false,
      theme: fixedTheme ?? AppTheme.light,
      darkTheme: fixedTheme ?? AppTheme.dark,
      themeMode: fixedTheme != null ? ThemeMode.light : themeMode,
      routerConfig: router,
    );
  }
}
