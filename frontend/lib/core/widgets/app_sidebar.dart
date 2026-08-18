import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../theme/theme_mode_provider.dart';
import 'notification_bell.dart';

const double sidebarExpandedWidth = 248;
const double sidebarRailWidth = 76;

/// Navegação lateral - alternativa ao `TopNavBar`, escolhida em
/// Configurações > Aparência (`nav_layout_provider.dart`). Usada tanto fixa
/// ao lado do conteúdo (desktop, `AppShell`) quanto dentro de um `Drawer`
/// (mobile) - nesse caso `collapsed` é sempre `false` (drawer sempre mostra
/// a versão cheia). O botão de colapsar/expandir NÃO mora aqui - é um
/// `Positioned` flutuante em `AppShell`, sobre a borda entre sidebar e
/// conteúdo, pra manter a mesma posição visual aberta ou fechada (ver
/// `_SidebarCollapseToggle`).
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.currentPath,
    required this.onNavigate,
    required this.collapsed,
  });

  final String currentPath;
  final ValueChanged<String> onNavigate;
  final bool collapsed;

  static const _items = [
    (path: '/dashboard', label: 'Painel', icon: Icons.dashboard_outlined),
    (path: '/tasks', label: 'Tarefas', icon: Icons.check_box_outlined),
    (path: '/projects', label: 'Projetos', icon: Icons.folder_outlined),
    (path: '/notes', label: 'Anotações', icon: Icons.description_outlined),
    (path: '/focus', label: 'Foco', icon: Icons.timer_outlined),
    (path: '/statistics', label: 'Estatísticas', icon: Icons.bar_chart_outlined),
    (path: '/settings', label: 'Configurações', icon: Icons.settings_outlined),
  ];

  bool _isActive(String tabPath) {
    if (tabPath == '/dashboard') return currentPath == tabPath;
    return currentPath == tabPath || currentPath.startsWith(tabPath);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(appThemeModeProvider);
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    return Material(
      color: theme.cardTheme.color ?? colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Align(
                alignment: collapsed ? Alignment.center : Alignment.centerLeft,
                child: InkWell(
                  onTap: () => onNavigate('/dashboard'),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.check_box_outlined,
                          size: 20,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      if (!collapsed) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Flown',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 12, vertical: 4),
                children: [
                  for (final item in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _SidebarNavItem(
                        label: item.label,
                        icon: item.icon,
                        active: _isActive(item.path),
                        collapsed: collapsed,
                        onTap: () => onNavigate(item.path),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const NotificationBell(anchorAbove: true),
                  IconButton(
                    tooltip: isDark ? 'Modo claro' : 'Modo escuro',
                    onPressed: () => ref
                        .read(appThemeModeProvider.notifier)
                        .toggle(isDark ? Brightness.dark : Brightness.light),
                    icon: Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.collapsed,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = active ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    if (collapsed) {
      return Tooltip(
        message: label,
        child: Material(
          color: active ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
        ),
      );
    }

    return Material(
      color: active ? colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

