import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project.dart';
import '../../../core/models/task.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/badge_size.dart';
import '../../../core/widgets/global_search_field.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../../core/widgets/screen_gradient_backdrop.dart';
import '../../../core/widgets/status_badge.dart';
import '../../notes/providers/note_list_controller.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../projects/providers/project_type_repository.dart';
import '../../statistics/providers/dashboard_stats_repository.dart';
import '../../tasks/providers/task_list_controller.dart';
import '../../tasks/utils/task_hierarchy.dart';
import '../../tasks/utils/task_status_colors.dart';
import '../utils/dashboard_derivations.dart';
import '../widgets/hero_metrics_panel.dart';

/// Tela inicial — tradução de Dashboard.tsx
/// (docs/prototype/screens/dashboard.md), mas com todo número derivado de
/// dados reais (`TaskListController`, `NoteListController`,
/// `GET /dashboard/stats`) em vez do array `mockTasks` estático do
/// protótipo. Ver `dashboard_derivations.dart` pra como cada seção calcula
/// seus números. Sem as partículas flutuantes animadas do protótipo
/// ("tema fantasy") — só o wash de gradiente no topo
/// (`ScreenGradientBackdrop`), pedido à parte pra essa e outras 4 telas.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final taskListAsync = ref.watch(taskListControllerProvider);
    final noteListAsync = ref.watch(noteListControllerProvider);
    final projectListAsync = ref.watch(projectListControllerProvider);
    final projectTypeListAsync = ref.watch(projectTypeListProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return ScreenGradientBackdrop(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Painel',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Bem-vindo! Aqui está o que está acontecendo hoje.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                );

                // Busca global cross-entidade mora aqui, não na navegação -
                // ver global_search_field.dart.
                if (constraints.maxWidth < 700) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 12),
                      GlobalSearchField(width: constraints.maxWidth),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: title),
                    const GlobalSearchField(),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            taskListAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('Erro ao carregar tarefas: $error')),
              ),
              data: (allTasks) {
                // Subtarefas não contam pro Dashboard — só as tarefas de
                // nível superior.
                final tasks = topLevelTasks(allTasks);
                final notes = noteListAsync.valueOrNull ?? const [];
                final projects = projectListAsync.valueOrNull ?? const [];
                final projectTypes =
                    projectTypeListAsync.valueOrNull ?? const [];
                final projectsById = {for (final p in projects) p.id: p};
                final statusOrder = resolveStatusOrder(projectTypes, tasks);
                final weeklySummary = computeWeeklyProductivitySummary(
                  statsAsync.valueOrNull?.productivity.heatmap ?? const [],
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeroMetricsPanel(
                      tasks: tasks,
                      onTapOverdue: () => context.go('/tasks?overdue=true'),
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final focusCard = _CurrentFocusCard(
                          task: findCurrentFocusTask(tasks),
                          project:
                              projectsById[findCurrentFocusTask(
                                tasks,
                              )?.projectId],
                        );
                        final weekly = _WeeklyProductivityCard(
                          summary: weeklySummary,
                        );

                        if (constraints.maxWidth < 700) {
                          return Column(
                            children: [
                              focusCard,
                              const SizedBox(height: 24),
                              weekly,
                            ],
                          );
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 2, child: focusCard),
                              const SizedBox(width: 24),
                              Expanded(child: weekly),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final upcoming = _UpcomingTasksCard(
                          tasks: computeUpcomingTasks(tasks),
                          projectsById: projectsById,
                          statusOrder: statusOrder,
                        );
                        final overview = _TaskOverviewCard(
                          createdThisWeek: countCreatedThisWeek(tasks),
                          completedThisWeek: weeklySummary.total,
                          breakdown: computeStatusBreakdown(tasks),
                        );

                        if (constraints.maxWidth < 700) {
                          return Column(
                            children: [
                              upcoming,
                              const SizedBox(height: 24),
                              overview,
                            ],
                          );
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 2, child: upcoming),
                              const SizedBox(width: 24),
                              Expanded(child: overview),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _RecentActivityCard(
                      entries: computeRecentActivity(tasks, notes),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}


/// "Foco Atual" — só a primeira task `In Progress` + prioridade alta (ver
/// `findCurrentFocusTask`), igual ao protótipo.
class _CurrentFocusCard extends StatelessWidget {
  const _CurrentFocusCard({required this.task, required this.project});

  final Task? task;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = task;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.track_changes_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Foco Atual',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/focus'),
                icon: const Icon(Icons.center_focus_strong_outlined, size: 16),
                label: const Text('Entrar em Modo Foco'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (current == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.track_changes_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhuma tarefa em foco',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/tasks'),
                      child: const Text('Selecionar uma Tarefa'),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.title,
                            style: theme.textTheme.titleLarge,
                          ),
                          if ((current.description ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              current.description!,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    PriorityBadge(
                      priority: current.priority,
                      size: BadgeSize.md,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Projeto: ',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      project?.name ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Vencimento: ',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      current.dueDate == null
                          ? '—'
                          : DateFormat('dd/MM/yyyy').format(current.dueDate!),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progresso',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${current.progress ?? 0}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (current.progress ?? 0) / 100,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                if (current.checklist.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${current.checklist.where((c) => c.done).length} de ${current.checklist.length} itens concluídos',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _UpcomingTasksCard extends StatelessWidget {
  const _UpcomingTasksCard({
    required this.tasks,
    required this.projectsById,
    required this.statusOrder,
  });

  final List<Task> tasks;
  final Map<String, Project> projectsById;
  final List<String> statusOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Próximas Tarefas',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/tasks'),
                child: const Text('Ver Tudo'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Nenhuma tarefa pendente',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            for (final task in tasks)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                projectsById[task.projectId]?.name ?? '—',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                ' • ',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                task.dueDate == null
                                    ? 'Sem prazo'
                                    : 'Vencimento ${DateFormat('dd/MM/yyyy').format(task.dueDate!)}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PriorityBadge(priority: task.priority),
                    const SizedBox(width: 8),
                    StatusBadge(
                      label: statusLabelPtBr(task.status),
                      colorIndex: statusOrder
                          .indexOf(task.status)
                          .clamp(0, statusOrder.length - 1),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${task.progress ?? 0}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _WeeklyProductivityCard extends StatelessWidget {
  const _WeeklyProductivityCard({required this.summary});

  final WeeklyProductivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxCount = summary.points
        .map((p) => p.count)
        .fold<int>(0, (max, v) => v > max ? v : max);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 20),
              const SizedBox(width: 8),
              Text(
                'Esta Semana',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: (maxCount == 0 ? 1 : maxCount) * 1.2,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      interval: 1,
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 ||
                            index >= summary.points.length ||
                            index != value) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            summary.points[index].dayLabel,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < summary.points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: summary.points[i].count.toDouble(),
                          color: colorScheme.primary,
                          width: 18,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Concluído',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              Text(
                '${summary.total} tarefas',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Média Diária',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              Text(
                '${summary.dailyAverage.toStringAsFixed(1)} tarefas',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Substitui a posição original de "Esta Semana" (que subiu pra ficar ao
/// lado de "Foco Atual") - criadas/concluídas na semana + distribuição fixa
/// de status em barras (A Fazer/Em Andamento/Atrasada/Concluída), inspirado
/// no `_StatusPieChart` da tela de Estatísticas mas em barra e com grupos
/// fixos em vez do `status` dinâmico por `ProjectType` (ver
/// `computeStatusBreakdown`).
class _TaskOverviewCard extends StatelessWidget {
  const _TaskOverviewCard({
    required this.createdThisWeek,
    required this.completedThisWeek,
    required this.breakdown,
  });

  final int createdThisWeek;
  final int completedThisWeek;
  final StatusBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semanticColors;

    final groups = [
      (label: 'A Fazer', value: breakdown.todo, color: colorScheme.secondary),
      (label: 'Andamento', value: breakdown.inProgress, color: semantic.priorityMedium),
      (label: 'Atrasada', value: breakdown.overdue, color: semantic.priorityHigh),
      (label: 'Concluída', value: breakdown.completed, color: semantic.priorityLow),
    ];
    final maxValue = groups.map((g) => g.value).fold<int>(0, (max, v) => v > max ? v : max);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Visão Geral',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Criadas Esta Semana', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
              Text('$createdThisWeek', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Concluídas Esta Semana', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
              Text('$completedThisWeek', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: (maxValue == 0 ? 1 : maxValue) * 1.2,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= groups.length || index != value) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(groups[index].label, style: const TextStyle(fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < groups.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: groups[i].value.toDouble(),
                          color: groups[i].color,
                          width: 28,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.entries});

  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Atividade Recente',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Nenhuma atividade ainda',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        entry.icon,
                        size: 16,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            entry.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm').format(entry.timestamp),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
