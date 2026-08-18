import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notes/widgets/note_form_dialog.dart';
import '../../features/projects/widgets/project_form_dialog.dart';
import '../../features/tasks/widgets/task_form_dialog.dart';
import '../navigation/nav_layout_provider.dart';
import '../theme/app_theme.dart';
import 'app_sidebar.dart';
import 'global_floating_action_button.dart';
import 'top_nav_bar.dart';

const double _wideBreakpoint = 900;

/// Casca comum das telas autenticadas. Layout escolhido em Configurações >
/// Aparência > Navegação (`nav_layout_provider.dart`):
///   - `NavLayout.topBar` — layout original (`TopNavBar` fixo no topo),
///     preservado como estava, não é removido nem alterado;
///   - `NavLayout.sidebar` (padrão novo) — `AppSidebar` fixa ao lado do
///     conteúdo em telas largas (>= 900px, colapsável pra rail só de
///     ícone), ou dentro de um `Drawer` acionado por um botão de hambúrguer
///     em telas estreitas (a primeira navegação do app pensada pra
///     celular).
///
/// `GlobalFloatingActionButton` continua igual nos dois layouts — não foi
/// pedido pra mudar, e a criação rápida de task/project/note já funciona
/// bem como está.
///
/// A única rota que NÃO usa esse layout é `/focus` (tela cheia imersiva,
/// sem nenhum shell) — fica fora do `ShellRoute` em `app_router.dart`.
class AppShell extends ConsumerStatefulWidget {
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
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _railCollapsed = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _fab(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: GlobalFloatingActionButton(
        currentPath: widget.currentPath,
        onCreateTask: () => showTaskFormDialog(context),
        onCreateProject: () => showProjectFormDialog(context),
        onCreateNote: () => showNoteFormDialog(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navLayout = ref.watch(appNavLayoutProvider).valueOrNull ?? NavLayout.sidebar;

    if (navLayout == NavLayout.topBar) {
      return Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                TopNavBar(currentPath: widget.currentPath, onNavigate: widget.onDestinationSelected),
                Expanded(child: widget.child),
              ],
            ),
            _fab(context),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideBreakpoint) {
          final sidebarWidth = _railCollapsed ? sidebarRailWidth : sidebarExpandedWidth;
          return Scaffold(
            body: Stack(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: sidebarWidth,
                      child: AppSidebar(
                        currentPath: widget.currentPath,
                        onNavigate: widget.onDestinationSelected,
                        collapsed: _railCollapsed,
                      ),
                    ),
                    VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
                    Expanded(child: Stack(children: [widget.child, _fab(context)])),
                  ],
                ),
                // Flutuante, sobreposto à borda entre sidebar e conteúdo -
                // fica na mesma posição aberta ou fechada (só `sidebarWidth`
                // muda), em vez de pular de lugar como um chevron inline no
                // cabeçalho faria.
                Positioned(
                  top: 24,
                  left: sidebarWidth - 12,
                  child: _SidebarCollapseToggle(
                    collapsed: _railCollapsed,
                    onTap: () => setState(() => _railCollapsed = !_railCollapsed),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          drawer: Drawer(
            width: sidebarExpandedWidth,
            child: AppSidebar(
              currentPath: widget.currentPath,
              collapsed: false,
              onNavigate: (path) {
                _scaffoldKey.currentState?.closeDrawer();
                widget.onDestinationSelected(path);
              },
            ),
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  _MobileTopBar(onOpenMenu: () => _scaffoldKey.currentState?.openDrawer()),
                  Expanded(child: widget.child),
                ],
              ),
              _fab(context),
            ],
          ),
        );
      },
    );
  }
}

/// Badge circular que colapsa/expande a sidebar - metade pra dentro, metade
/// pra fora dela (centro horizontal em cima da borda), mesma posição
/// vertical fixa nos dois estados.
class _SidebarCollapseToggle extends StatelessWidget {
  const _SidebarCollapseToggle({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.sharp),
      side: BorderSide(color: colorScheme.outlineVariant),
    );

    return Material(
      color: theme.cardTheme.color ?? colorScheme.surface,
      shape: shape,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            collapsed ? Icons.chevron_right : Icons.chevron_left,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Faixa mínima só pra abrir o `Drawer` em tela estreita - ocupa um espaço
/// real no layout (`Column`), não flutua sobre o conteúdo: cada uma das 11
/// telas já tem seu próprio padding/cabeçalho encostado no topo, um botão
/// `Positioned` ali por cima ia sobrepor esse conteúdo em vez de conviver
/// com ele.
class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.onOpenMenu});

  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: theme.cardTheme.color ?? colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Menu',
                onPressed: onOpenMenu,
                icon: const Icon(Icons.menu),
              ),
              Text(
                'Flown',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
