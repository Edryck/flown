import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_mode_provider.dart';

/// Cabeçalho fixo do app — tradução de TopNavBar.tsx
/// (docs/prototype/components/top-nav-bar.md): logo, abas de navegação,
/// busca global, atalho de configurações, toggle de tema.
///
/// Diferenças deliberadas do protótipo:
///   - "Busca" aqui é a própria busca global já ligada à rota real
///     (`/search`), em vez de decorativa como no protótipo (ver
///     docs/prototype/00-overview.md);
///   - "Lixeira" não é aba — mora dentro de Configurações
///     (`SettingsScreen`), já que o protótipo não modela lixeira em lugar
///     nenhum e não tem essa rota entre as 6 abas originais;
///   - sem botão "Nova Tarefa" nem avatar decorativo — o FAB
///     (`GlobalFloatingActionButton`) já cobre "criar tarefa" em toda tela,
///     manter os dois era redundante (o protótipo tinha essa duplicação);
///     o avatar não fazia nada (sem `onClick` no protótipo, sem handler
///     aqui) — a conta de verdade mora em Configurações agora, como
///     primeira seção.
class TopNavBar extends ConsumerStatefulWidget {
  const TopNavBar({super.key, required this.currentPath, required this.onNavigate});

  final String currentPath;
  final ValueChanged<String> onNavigate;

  @override
  ConsumerState<TopNavBar> createState() => _TopNavBarState();
}

class _TopNavBarState extends ConsumerState<TopNavBar> {
  final _searchController = TextEditingController();

  static const _tabs = [
    (path: '/dashboard', label: 'Painel'),
    (path: '/tasks', label: 'Tarefas'),
    (path: '/projects', label: 'Projetos'),
    (path: '/notes', label: 'Anotações'),
    (path: '/focus', label: 'Foco'),
    (path: '/statistics', label: 'Estatísticas'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isActive(String tabPath) {
    if (tabPath == '/dashboard') return widget.currentPath == tabPath;
    return widget.currentPath == tabPath || widget.currentPath.startsWith(tabPath);
  }

  void _submitSearch(String query) {
    final trimmed = query.trim();
    widget.onNavigate(trimmed.isEmpty ? '/search' : '/search?q=$trimmed');
  }

  @override
  Widget build(BuildContext context) {
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
      elevation: 1,
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              InkWell(
                onTap: () => widget.onNavigate('/dashboard'),
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
                      child: Icon(Icons.check_box_outlined, size: 20, color: colorScheme.onPrimary),
                    ),
                    const SizedBox(width: 8),
                    Text('Flown', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tab in _tabs)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _NavTab(
                            label: tab.label,
                            active: _isActive(tab.path),
                            onTap: () => widget.onNavigate(tab.path),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 256,
                height: 36,
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _submitSearch,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Pesquisar tarefas, anotações...',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Configurações',
                onPressed: () => widget.onNavigate('/settings'),
                icon: const Icon(Icons.settings_outlined, size: 20),
              ),
              IconButton(
                tooltip: isDark ? 'Modo claro' : 'Modo escuro',
                onPressed: () => ref
                    .read(appThemeModeProvider.notifier)
                    .toggle(isDark ? Brightness.dark : Brightness.light),
                icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: active ? colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: active ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
