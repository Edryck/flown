import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project.dart';
import '../../../core/models/task.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/badge_size.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../../core/widgets/screen_gradient_backdrop.dart';
import '../../../core/widgets/status_badge.dart';
import '../../notes/providers/note_list_controller.dart';
import '../../notes/widgets/note_form_dialog.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../projects/providers/project_type_repository.dart';
import '../../statistics/providers/dashboard_stats_repository.dart';
import '../../tasks/providers/task_list_controller.dart';
import '../../tasks/utils/task_hierarchy.dart';
import '../../tasks/utils/task_status_colors.dart';
import '../../tasks/widgets/task_form_dialog.dart';
import '../utils/dashboard_derivations.dart';

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
            Text(
              'Painel',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Bem-vindo! Aqui está o que está acontecendo hoje.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
                final overdue = countOverdue(tasks);
                final weeklySummary = computeWeeklyProductivitySummary(
                  statsAsync.valueOrNull?.productivity.heatmap ?? const [],
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricsRow(tasks: tasks),
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
                        final quickActions = _QuickActionsCard(
                          overdueCount: overdue,
                        );

                        if (constraints.maxWidth < 700) {
                          return Column(
                            children: [
                              focusCard,
                              const SizedBox(height: 24),
                              quickActions,
                            ],
                          );
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 2, child: focusCard),
                              const SizedBox(width: 24),
                              Expanded(child: quickActions),
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
                        final weekly = _WeeklyProductivityCard(
                          summary: weeklySummary,
                        );

                        if (constraints.maxWidth < 700) {
                          return Column(
                            children: [
                              upcoming,
                              const SizedBox(height: 24),
                              weekly,
                            ],
                          );
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 2, child: upcoming),
                              const SizedBox(width: 24),
                              Expanded(child: weekly),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;

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
          childAspectRatio: 2.6,
          children: [
            MetricCard(
              title: 'Vencimento Hoje',
              value: '${countDueToday(tasks)}',
              icon: Icons.schedule_outlined,
              iconColor: const Color(0xFF2B6CB0),
            ),
            MetricCard(
              title: 'Tarefas Atrasadas',
              value: '${countOverdue(tasks)}',
              icon: Icons.error_outline,
              iconColor: semantic.priorityHigh,
            ),
            MetricCard(
              title: 'Concluído Hoje',
              value: '${countCompletedToday(tasks)}',
              icon: Icons.check_circle_outline,
              iconColor: semantic.priorityLow,
            ),
            MetricCard(
              title: 'Em Andamento',
              value: '${countInProgress(tasks)}',
              icon: Icons.track_changes_outlined,
              iconColor: semantic.priorityMedium,
            ),
          ],
        );
      },
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

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.overdueCount});

  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ações Rápidas',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showTaskFormDialog(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Align(
              alignment: Alignment.centerLeft,
              child: Text('Criar Tarefa'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/focus'),
            icon: const Icon(Icons.center_focus_strong_outlined, size: 16),
            label: const Align(
              alignment: Alignment.centerLeft,
              child: Text('Modo Foco'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => showNoteFormDialog(context),
            icon: const Icon(Icons.description_outlined, size: 16),
            label: const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nova Anotação'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/tasks'),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Align(
              alignment: Alignment.centerLeft,
              child: Text('Ver Atrasadas'),
            ),
          ),
          if (overdueCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: semantic.priorityHighContainer,
                border: Border.all(
                  color: semantic.priorityHigh.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 20,
                    color: semantic.priorityHigh,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tarefas Atrasadas',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: semantic.priorityHigh,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Você tem $overdueCount ${overdueCount == 1 ? 'tarefa atrasada' : 'tarefas atrasadas'} que '
                          'precisa${overdueCount == 1 ? '' : 'm'} de atenção',
                          style: TextStyle(
                            color: semantic.priorityHigh.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                            index != value)
                          return const SizedBox.shrink();
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
