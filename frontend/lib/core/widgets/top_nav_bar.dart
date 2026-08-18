import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notes/widgets/note_form_dialog.dart';
import '../../features/projects/widgets/project_view_dialog.dart';
import '../../features/search/providers/search_repository.dart';
import '../../features/tasks/widgets/task_view_dialog.dart';
import '../models/note.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../theme/theme_mode_provider.dart';
import 'notification_bell.dart';
import 'search_results_panel.dart';

/// Cabeçalho fixo do app — tradução de TopNavBar.tsx
/// (docs/prototype/components/top-nav-bar.md): logo, abas de navegação,
/// busca global, atalho de configurações, toggle de tema.
///
/// Diferenças deliberadas do protótipo:
///   - "Busca" é busca global de verdade (`GET /search?q=`, `SearchRepository`),
///     não decorativa como no protótipo (docs/prototype/00-overview.md) — mas
///     também não é mais uma rota/tela própria: os resultados aparecem num
///     dropdown ancorado no próprio campo (`OverlayPortal` +
///     `CompositedTransformFollower`), igual à ideia de "busca global na
///     navbar" pedida — clicar num resultado navega pra tela certa e já abre
///     o item no modal correspondente: modo visualização pra Task/Project
///     (mesmo diálogo que os cards abrem), form de edição pra Note (sem
///     diálogo de visualização próprio — mesmo padrão do clique em
///     `NoteCard`). Fechar ao clicar fora usa
///     `TapRegion` com `groupId`, mesmo mecanismo de
///     `GlobalFloatingActionButton` (mas precisa de `groupId` aqui porque o
///     painel de resultados mora na `Overlay`, fora da subárvore do campo);
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
  const TopNavBar({
    super.key,
    required this.currentPath,
    required this.onNavigate,
  });

  final String currentPath;
  final ValueChanged<String> onNavigate;

  @override
  ConsumerState<TopNavBar> createState() => _TopNavBarState();
}

class _TopNavBarState extends ConsumerState<TopNavBar> {
  static const _searchFieldWidth = 340.0;
  static const _searchPanelWidth = 340.0;
  static const _searchGroupId = 'top-nav-global-search';

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _searchLayerLink = LayerLink();
  final _searchOverlayController = OverlayPortalController();
  Timer? _debounce;
  Future<SearchResults>? _searchFuture;

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
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _isActive(String tabPath) {
    if (tabPath == '/dashboard') return widget.currentPath == tabPath;
    return widget.currentPath == tabPath ||
        widget.currentPath.startsWith(tabPath);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _searchFuture = null);
      _searchOverlayController.hide();
      return;
    }
    // Debounce de propósito — sem isso, cada tecla dispara uma chamada a
    // `GET /search` (nenhum cancelamento de request in-flight no
    // `SearchRepository`, então respostas fora de ordem poderiam sobrescrever
    // o resultado mais recente).
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      // Bloco (não `=>`) de propósito — uma arrow function aqui retornaria a
      // própria `Future` de `.search()` como valor do closure, e o Flutter
      // recusa um callback de `setState` que devolve uma `Future` (era
      // exatamente isso que quebrava a busca: `DartError: setState()
      // callback argument returned a Future`).
      setState(() {
        _searchFuture = ref.read(searchRepositoryProvider).search(query);
      });
      _searchOverlayController.show();
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    _searchOverlayController.hide();
    _searchController.clear();
    setState(() => _searchFuture = null);
  }

  void _openTask(Task task) {
    _closeSearch();
    widget.onNavigate('/tasks');
    showTaskViewDialog(context, task: task);
  }

  void _openProject(Project project) {
    _closeSearch();
    widget.onNavigate('/projects');
    showProjectViewDialog(context, project: project);
  }

  void _openNote(Note note) {
    _closeSearch();
    widget.onNavigate('/notes');
    showNoteFormDialog(context, note: note);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(appThemeModeProvider);
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
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
                      child: Icon(
                        Icons.check_box_outlined,
                        size: 20,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Flown',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
              CompositedTransformTarget(
                link: _searchLayerLink,
                child: TapRegion(
                  groupId: _searchGroupId,
                  onTapOutside: (_) {
                    if (_searchFuture != null) _closeSearch();
                  },
                  child: OverlayPortal(
                    controller: _searchOverlayController,
                    overlayChildBuilder: (context) =>
                        CompositedTransformFollower(
                          link: _searchLayerLink,
                          showWhenUnlinked: false,
                          targetAnchor: Alignment.bottomLeft,
                          offset: const Offset(
                            -(_searchPanelWidth - _searchFieldWidth),
                            8,
                          ),
                          child: TapRegion(
                            groupId: _searchGroupId,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: SearchResultsPanel(
                                width: _searchPanelWidth,
                                future: _searchFuture,
                                onTapTask: _openTask,
                                onTapProject: _openProject,
                                onTapNote: _openNote,
                              ),
                            ),
                          ),
                        ),
                    child: SizedBox(
                      width: _searchFieldWidth,
                      height: 36,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: _closeSearch,
                                ),
                          hintText: 'Buscar tarefas, projetos, anotações...',
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const NotificationBell(),
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
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

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
              color: active
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

