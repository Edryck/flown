import 'package:flutter/material.dart';

import '../../features/notes/widgets/note_form_dialog.dart';
import '../../features/projects/widgets/project_form_dialog.dart';
import '../../features/tasks/widgets/task_form_dialog.dart';
import 'global_floating_action_button.dart';
import 'top_nav_bar.dart';

/// Casca comum das telas autenticadas — tradução fiel do `RootLayout` do
/// protótipo (`routes.tsx`): `TopNavBar` fixo no topo + conteúdo da rota
/// atual + `GlobalFloatingActionButton` flutuante no canto inferior
/// direito. Ver docs/prototype/00-overview.md e
/// docs/prototype/components/{top-nav-bar,global-floating-action-button}.md.
///
/// A única rota do protótipo que NÃO usa esse layout é `/focus` (tela cheia
/// imersiva, sem TopNavBar/FAB) — por isso `/focus` fica fora do
/// `ShellRoute` em `app_router.dart`, igual à divisão de `routes.tsx`.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentPath,
    required this.onDestinationSelected,
    required this.child,
  });

  final String currentPath;
  final ValueChanged<String> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              TopNavBar(currentPath: currentPath, onNavigate: onDestinationSelected),
              Expanded(child: child),
            ],
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: GlobalFloatingActionButton(
              currentPath: currentPath,
              onCreateTask: () => showTaskFormDialog(context),
              onCreateProject: () => showProjectFormDialog(context),
              onCreateNote: () => showNoteFormDialog(context),
            ),
          ),
        ],
      ),
    );
  }
}
