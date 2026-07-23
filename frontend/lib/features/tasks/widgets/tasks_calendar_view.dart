import 'package:flutter/material.dart';

import '../../../core/models/task.dart';
import '../../../core/models/task_priority.dart';
import '../../../core/theme/semantic_colors.dart';

/// Grade de calendário mensal — tradução fiel de TasksCalendarView.tsx
/// (docs/prototype/components/tasks-calendar-view.md): navegação de mês,
/// botão "Hoje", até 3 tasks por dia (com "+N mais"), legenda de
/// prioridade + destaque do dia atual. Sem busca (igual ao protótipo — essa
/// view não recebe `searchQuery`, mostra sempre todas as tasks).
///
/// `isOverdue` usa `task.completedAt == null` em vez de `status !== 'done'`
/// — mesma adaptação já feita em `TasksTableView`/`TasksKanbanView`.
///
/// Diferente do protótipo, cada chip de task é clicável: `onTapTask` abre a
/// task em `TaskFormScreen` pra editar/mudar status/marcar como concluída
/// — o protótipo não tinha nenhuma ação de clique aqui.
class TasksCalendarView extends StatefulWidget {
  const TasksCalendarView({super.key, required this.tasks, required this.onTapTask});

  final List<Task> tasks;
  final ValueChanged<Task> onTapTask;

  @override
  State<TasksCalendarView> createState() => _TasksCalendarViewState();
}

class _TasksCalendarViewState extends State<TasksCalendarView> {
  late DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static const _dayNames = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  void _previousMonth() => setState(() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
  });

  void _nextMonth() => setState(() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
  });

  void _goToToday() => setState(() {
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
  });

  List<Task> _tasksForDate(DateTime date) {
    return widget.tasks.where((task) {
      final due = task.dueDate;
      if (due == null) return false;
      return due.year == date.year && due.month == date.month && due.day == date.day;
    }).toList();
  }

  bool _isOverdue(Task task) {
    if (task.completedAt != null || task.dueDate == null) return false;
    final today = DateTime.now();
    final due = task.dueDate!;
    return DateTime(due.year, due.month, due.day).isBefore(DateTime(today.year, today.month, today.day));
  }

  Color _priorityDotColor(TaskPriority priority, AppSemanticColors semantic) => switch (priority) {
    TaskPriority.high => semantic.priorityHigh,
    TaskPriority.medium => semantic.priorityMedium,
    TaskPriority.low => semantic.priorityLow,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final today = DateTime.now();

    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday % 7; // 0 = domingo .. 6 = sábado

    final totalCells = startingWeekday + daysInMonth;
    final trailingEmpty = (7 - totalCells % 7) % 7;

    final cells = <Widget>[
      for (var i = 0; i < startingWeekday; i++) _EmptyDayCell(colorScheme: colorScheme),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          day: day,
          isToday: DateTime(_currentMonth.year, _currentMonth.month, day) ==
              DateTime(today.year, today.month, today.day),
          tasks: _tasksForDate(DateTime(_currentMonth.year, _currentMonth.month, day)),
          isOverdue: _isOverdue,
          priorityDotColor: (p) => _priorityDotColor(p, semantic),
          semantic: semantic,
          colorScheme: colorScheme,
          theme: theme,
          onTapTask: widget.onTapTask,
        ),
      for (var i = 0; i < trailingEmpty; i++) _EmptyDayCell(colorScheme: colorScheme),
    ];

    final rows = <TableRow>[
      TableRow(
        children: [
          for (final name in _dayNames)
            Container(
              height: 40,
              color: colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Text(name, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500)),
            ),
        ],
      ),
      for (var i = 0; i < cells.length; i += 7) TableRow(children: cells.sublist(i, i + 7)),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _previousMonth,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(36, 36)),
                    child: const Icon(Icons.chevron_left, size: 18),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _goToToday, child: const Text('Hoje')),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _nextMonth,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(8), minimumSize: const Size(36, 36)),
                    child: const Icon(Icons.chevron_right, size: 18),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Table(
              border: TableBorder.all(color: colorScheme.outlineVariant, width: 1),
              children: rows,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LegendDot(color: semantic.priorityHigh, label: 'Alta Prioridade'),
              _LegendDot(color: semantic.priorityMedium, label: 'Média Prioridade'),
              _LegendDot(color: semantic.priorityLow, label: 'Baixa Prioridade'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: colorScheme.primary, width: 2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Hoje', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyDayCell extends StatelessWidget {
  const _EmptyDayCell({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(height: 120, color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3));
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.tasks,
    required this.isOverdue,
    required this.priorityDotColor,
    required this.semantic,
    required this.colorScheme,
    required this.theme,
    required this.onTapTask,
  });

  final int day;
  final bool isToday;
  final List<Task> tasks;
  final bool Function(Task) isOverdue;
  final Color Function(TaskPriority) priorityDotColor;
  final AppSemanticColors semantic;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final ValueChanged<Task> onTapTask;

  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks.take(3).toList();
    final remaining = tasks.length - visibleTasks.length;

    return Container(
      height: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: isToday ? Border.all(color: colorScheme.primary, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              isToday
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        '$day',
                        style: TextStyle(color: colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    )
                  : Text('$day', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              if (tasks.isNotEmpty)
                Text(
                  '${tasks.length}',
                  style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final task in visibleTasks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => onTapTask(task),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                isOverdue(task) ? semantic.priorityHighContainer : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isOverdue(task)
                                  ? semantic.priorityHigh.withValues(alpha: 0.2)
                                  : colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration:
                                    BoxDecoration(color: priorityDotColor(task.priority), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOverdue(task) ? semantic.priorityHigh : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (remaining > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '+$remaining mais',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
