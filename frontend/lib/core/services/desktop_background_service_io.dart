import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Chamado uma vez no boot (Desktop) - fechar a janela (botão X) minimiza
/// pra bandeja em vez de encerrar o processo, pra tarefas vencendo
/// continuarem sendo notificadas mesmo com o app "fechado" (só sai de
/// verdade pelo menu da bandeja). Ver `task_reminder_watcher.dart` pra quem
/// realmente dispara as notificações.
Future<void> initDesktopBackgroundService() async {
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  windowManager.addListener(_AppWindowListener());

  await localNotifier.setup(appName: 'Flown');

  await trayManager.setIcon('assets/icons/tray_icon.ico');
  await trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(label: 'Abrir Flown', onClick: (_) => _showWindow()),
        MenuItem.separator(),
        MenuItem(label: 'Sair', onClick: (_) => windowManager.destroy()),
      ],
    ),
  );
  trayManager.addListener(_AppTrayListener());
}

Future<void> _showWindow() async {
  await windowManager.show();
  await windowManager.focus();
}

class _AppWindowListener with WindowListener {
  @override
  void onWindowClose() {
    windowManager.hide();
  }
}

class _AppTrayListener with TrayListener {
  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }
}
