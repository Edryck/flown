import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/screen_gradient_backdrop.dart';
import '../../../core/widgets/stat_card.dart';
import '../../tasks/providers/task_list_controller.dart';
import '../providers/project_list_controller.dart';
import '../utils/project_stats.dart';
import '../widgets/project_card.dart';
import '../widgets/project_form_dialog.dart';
import '../widgets/project_view_dialog.dart';

enum _ProjectFilter { all, active, done, overdue }

enum _ProjectSort { name, progress, createdAt }

/// Tela de projetos — tradução fiel de Projects.tsx
/// (docs/prototype/screens/projects.md): 4 métricas, busca + 4 filtros
/// funcionais + ordenação, grade responsiva de cards (1/2/3 colunas).
///
/// Diferença deliberada do protótipo: as métricas/filtros/badges de
/// status/progresso/atraso não vêm de campos do `Project` (que não existem
/// no backend real) — são derivados das tasks de cada projeto
/// (`computeProjectStats`, `project_stats.dart`), usando a lista de tasks
/// já carregada por `TaskListController` (sem chamada extra por projeto).
class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _ProjectFilter _filter = _ProjectFilter.all;
  _ProjectSort _sort = _ProjectSort.name;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(projectListControllerProvider);
    final tasksAsync = ref.watch(taskListControllerProvider);

    return ScreenGradientBackdrop(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Projetos',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Organize e acompanhe seus projetos',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => showProjectFormDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Criar Projeto'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            projectsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('Erro ao carregar projetos: $error')),
              ),
              data: (projects) {
                final tasks = tasksAsync.valueOrNull ?? const <Task>[];
                final tasksByProject = <String, List<Task>>{};
                for (final task in tasks) {
                  final projectId = task.projectId;
                  if (projectId == null) continue;
                  (tasksByProject[projectId] ??= []).add(task);
                }
                final statsById = {
                  for (final p in projects)
                    p.id: computeProjectStats(tasksByProject[p.id] ?? const []),
                };

                final total = projects.length;
                final active = projects
                    .where((p) => !statsById[p.id]!.isDone)
                    .length;
                final done = projects
                    .where((p) => statsById[p.id]!.isDone)
                    .length;
                final overdue = projects
                    .where((p) => statsById[p.id]!.isOverdue)
                    .length;

                final query = _searchQuery.toLowerCase();
                var filtered = projects.where((p) {
                  if (query.isNotEmpty) {
                    final matches =
                        p.name.toLowerCase().contains(query) ||
                        (p.description ?? '').toLowerCase().contains(query);
                    if (!matches) return false;
                  }
                  final stats = statsById[p.id]!;
                  return switch (_filter) {
                    _ProjectFilter.all => true,
                    _ProjectFilter.active => !stats.isDone,
                    _ProjectFilter.done => stats.isDone,
                    _ProjectFilter.overdue => stats.isOverdue,
                  };
                }).toList();

                filtered.sort((a, b) {
                  return switch (_sort) {
                    _ProjectSort.name => a.name.toLowerCase().compareTo(
                      b.name.toLowerCase(),
                    ),
                    _ProjectSort.progress =>
                      statsById[b.id]!.progress.compareTo(
                        statsById[a.id]!.progress,
                      ),
                    _ProjectSort.createdAt => b.createdAt.compareTo(
                      a.createdAt,
                    ),
                  };
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricsRow(
                      total: total,
                      active: active,
                      done: done,
                      overdue: overdue,
                    ),
                    const SizedBox(height: 24),
                    _Toolbar(
                      searchController: _searchController,
                      onSearchChanged: (value) =>
                          setState(() => _searchQuery = value),
                      filter: _filter,
                      onFilterChanged: (f) => setState(() => _filter = f),
                      sort: _sort,
                      onSortChanged: (s) => setState(() => _sort = s),
                    ),
                    const SizedBox(height: 24),
                    if (filtered.isEmpty)
                      _EmptyState(
                        hasSearch: _searchQuery.isNotEmpty,
                        onCreate: () => showProjectFormDialog(context),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 1100
                              ? 3
                              : (constraints.maxWidth >= 700 ? 2 : 1);
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 24,
                              crossAxisSpacing: 24,
                              // Valor sensível a overflow de 1px (ver
                              // histórico: 260 já estourou antes com
                              // progresso + prazo juntos) - subiu de 232 pra
                              // 256 depois que o cabeçalho do card virou um
                              // bloco tintado com padding próprio (mais alto
                              // que a barra de 4px de antes), conferir
                              // visualmente se sobra/falta espaço.
                              mainAxisExtent: 256,
                            ),
                            itemBuilder: (context, index) {
                              final project = filtered[index];
                              return ProjectCard(
                                project: project,
                                stats: statsById[project.id]!,
                                onTap: () => showProjectViewDialog(
                                  context,
                                  project: project,
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Faixa única com os 4 números lado a lado - de propósito diferente do
/// 4 cards individuais, cada um com uma faixa colorida na lateral esquerda
/// (não um card cinza único com os números soltos dentro - isso já foi
/// tentado e ficou chapado/mal distribuído). Cada card tem identidade
/// própria (cor da faixa), diferente também do `HeroMetricsPanel` do
/// Dashboard (sem hero assimétrico aqui). Substitui o grid de 4 `MetricCard`
/// idênticos (cores hex fixas, ícone sangrando no canto) que tinha antes.
class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.total,
    required this.active,
    required this.done,
    required this.overdue,
  });

  final int total;
  final int active;
  final int done;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    final items = [
      (
        label: 'Total de Projetos',
        value: total,
        icon: Icons.folder_outlined,
        color: colorScheme.primary,
      ),
      (
        label: 'Ativos',
        value: active,
        icon: Icons.play_circle_outline,
        color: colorScheme.secondary,
      ),
      (
        label: 'Concluídos',
        value: done,
        icon: Icons.check_circle_outline,
        color: semantic.priorityLow,
      ),
      (
        label: 'Atrasados',
        value: overdue,
        icon: Icons.error_outline,
        color: overdue > 0 ? semantic.priorityHigh : colorScheme.onSurfaceVariant,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : (constraints.maxWidth >= 500 ? 2 : 1);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            for (final item in items)
              StatCard(
                label: item.label,
                value: '${item.value}',
                icon: item.icon,
                color: item.color,
              ),
          ],
        );
      },
    );
  }
}

/// Busca + Filtrar (diálogo) + Ordenar (menu) — mesmo padrão da tela de
/// Tasks (`task_filter_dialog.dart`/`_openSortMenu` em `tasks_screen.dart`),
/// não mais pílulas sempre visíveis: o usuário achou o toolbar de pílulas
/// poluído e preferiu o filtro escondido atrás de um botão, como já era em
/// Tasks. `_ProjectFilter` é seleção única (diferente de Tasks, que permite
/// combinar vários status/prioridades), então o diálogo usa `ChoiceChip`
/// (um grupo mutuamente exclusivo) em vez do `FilterChip` multi-seleção de
/// Tasks.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.onSearchChanged,
    required this.filter,
    required this.onFilterChanged,
    required this.sort,
    required this.onSortChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final _ProjectFilter filter;
  final ValueChanged<_ProjectFilter> onFilterChanged;
  final _ProjectSort sort;
  final ValueChanged<_ProjectSort> onSortChanged;

  static const _filterLabels = {
    _ProjectFilter.all: 'Todos',
    _ProjectFilter.active: 'Ativos',
    _ProjectFilter.done: 'Concluídos',
    _ProjectFilter.overdue: 'Atrasados',
  };

  static const _sortLabels = {
    _ProjectSort.name: 'Por Nome',
    _ProjectSort.progress: 'Por Progresso',
    _ProjectSort.createdAt: 'Por Data de Criação',
  };

  Future<void> _openFilterDialog(BuildContext context) async {
    final selected = await showDialog<_ProjectFilter>(
      context: context,
      builder: (context) => _ProjectFilterDialog(initial: filter),
    );
    if (selected != null) onFilterChanged(selected);
  }

  Future<void> _openSortMenu(BuildContext buttonContext) async {
    final button = buttonContext.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<_ProjectSort>(
      context: buttonContext,
      position: position,
      items: [
        for (final s in _ProjectSort.values)
          PopupMenuItem(value: s, child: Text(_sortLabels[s]!)),
      ],
    );
    if (selected != null) onSortChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            height: 36,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: 'Pesquisar projetos…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sharp),
                ),
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _openFilterDialog(context),
            icon: Icon(
              Icons.filter_list,
              size: 16,
              color: filter != _ProjectFilter.all
                  ? theme.colorScheme.primary
                  : null,
            ),
            label: Text(
              filter == _ProjectFilter.all
                  ? 'Filtrar'
                  : 'Filtrar: ${_filterLabels[filter]}',
            ),
          ),
          const SizedBox(width: 8),
          Builder(
            builder: (buttonContext) => OutlinedButton.icon(
              onPressed: () => _openSortMenu(buttonContext),
              icon: const Icon(Icons.sort, size: 16),
              label: Text('Ordenar: ${_sortLabels[sort]}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectFilterDialog extends StatefulWidget {
  const _ProjectFilterDialog({required this.initial});

  final _ProjectFilter initial;

  @override
  State<_ProjectFilterDialog> createState() => _ProjectFilterDialogState();
}

class _ProjectFilterDialogState extends State<_ProjectFilterDialog> {
  late _ProjectFilter _filter = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtrar projetos'),
      content: SizedBox(
        width: 320,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _ProjectFilter.values)
              ChoiceChip(
                label: Text(_Toolbar._filterLabels[f]!),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _filter = _ProjectFilter.all),
          child: const Text('Limpar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _filter),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSearch, required this.onCreate});

  final bool hasSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum projeto encontrado',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Tente ajustar sua busca'
                : 'Crie seu primeiro projeto para começar',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Criar Projeto'),
            ),
          ],
        ],
      ),
    );
  }
}
