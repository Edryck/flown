import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project.dart';
import '../../../core/models/task.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/priority_badge.dart';
import '../utils/task_status_colors.dart';

/// Quadro Kanban com drag-and-drop entre colunas — tradução fiel de
/// TasksKanbanView.tsx (docs/prototype/components/tasks-kanban-view.md):
/// card com título/prioridade/descrição truncada/até 2 tags/prazo/projeto/
/// progresso de checklist, coluna com contagem no cabeçalho e destaque ao
/// receber um card arrastado.
///
/// Diferença deliberada do protótipo (decisão registrada na tradução desta
/// tela): as colunas não são as 5 fixas do mock (`TaskStatus` do
/// protótipo) — vêm de `statusOrder` (`resolveStatusOrder`, calculado em
/// `TasksScreen` a partir de `ProjectType.availableStatus` de TODOS os
/// tipos de projeto cadastrados), então as colunas ficam prontas mesmo sem
/// nenhuma task ou projeto criado ainda — diferente de usar só os status já
/// em uso nas tasks, que deixava o quadro em branco quando a lista estava
/// vazia. Mover um card chama `onMove`, que faz `PATCH /tasks/:id` de
/// verdade (via `TaskListController.updateStatus`), não só estado local
/// como no protótipo. Tocar um card (sem segurar) chama `onTapTask`, que
/// abre o card em `TaskFormScreen` pra editar/mudar status/marcar como
/// concluída — o protótipo não tinha nenhuma ação de clique no card.
///
/// Cada card usa `LongPressDraggable` (segurar pra iniciar o arraste), não
/// `Draggable` puro — o card está dentro de uma coluna rolável (`ListView`)
/// e também é tocável (`onTapTask`); com `Draggable` simples, o
/// reconhecedor de arraste "imediato" entra em conflito com o scroll da
/// lista e com o toque, deixando ambos intermitentes. Exigir uma pressão
/// longa antes do arraste desambigua os três gestos de forma confiável.
///
/// `delay` usa `kLongPressTimeout` (500ms, o padrão do próprio Flutter pra
/// distinguir toque de pressão longa) — um valor menor (150ms testado antes)
/// fica perto demais da duração natural de um clique em mouse/trackpad, que
/// varia bastante entre dispositivos; cliques normais acabavam ultrapassando
/// esse delay e sendo reconhecidos como início de arraste, exigindo 2
/// cliques rápidos pra abrir a tarefa em vez de 1.
class TasksKanbanView extends StatelessWidget {
  const TasksKanbanView({
    super.key,
    required this.tasks,
    required this.projectsById,
    required this.statusOrder,
    required this.onMove,
    required this.onTapTask,
    required this.onViewSubtasks,
  });

  final List<Task> tasks;
  final Map<String, Project> projectsById;
  final List<String> statusOrder;
  final void Function(String taskId, String newStatus) onMove;
  final ValueChanged<Task> onTapTask;
  final ValueChanged<Task> onViewSubtasks;

  @override
  Widget build(BuildContext context) {
    if (statusOrder.isEmpty) {
      // Fallback defensivo — só acontece se nenhum ProjectType existir
      // ainda (nem o seed padrão), o que não deveria ocorrer em uso normal.
      final theme = Theme.of(context);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 64),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          'Nenhum status disponível ainda',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < statusOrder.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _KanbanColumn(
                status: statusOrder[i],
                colorIndex: i,
                tasks: tasks.where((t) => t.status == statusOrder[i]).toList(),
                projectsById: projectsById,
                onMove: onMove,
                onTapTask: onTapTask,
                onViewSubtasks: onViewSubtasks,
              ),
            ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatefulWidget {
  const _KanbanColumn({
    required this.status,
    required this.colorIndex,
    required this.tasks,
    required this.projectsById,
    required this.onMove,
    required this.onTapTask,
    required this.onViewSubtasks,
  });

  final String status;
  final int colorIndex;
  final List<Task> tasks;
  final Map<String, Project> projectsById;
  final void Function(String taskId, String newStatus) onMove;
  final ValueChanged<Task> onTapTask;
  final ValueChanged<Task> onViewSubtasks;

  @override
  State<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<_KanbanColumn> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semanticColors;

    return SizedBox(
      width: 320,
      height: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: semantic.statusContainerColorAt(widget.colorIndex),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant, width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    statusLabelPtBr(widget.status),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${widget.tasks.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<Task>(
              onWillAcceptWithDetails: (details) =>
                  details.data.status != widget.status,
              onAcceptWithDetails: (details) =>
                  widget.onMove(details.data.id, widget.status),
              builder: (context, candidateData, rejectedData) {
                final isOver = candidateData.isNotEmpty;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOver
                        ? colorScheme.primary.withValues(alpha: 0.08)
                        : colorScheme.surfaceContainerLowest,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  child: widget.tasks.isEmpty
                      ? Center(
                          child: Text(
                            'Solte tarefas aqui',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: widget.tasks.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final task = widget.tasks[index];
                            return LongPressDraggable<Task>(
                              data: task,
                              delay: kLongPressTimeout,
                              feedback: Material(
                                color: Colors.transparent,
                                child: SizedBox(
                                  width: 296,
                                  child: Transform.rotate(
                                    angle: 0.03,
                                    child: _KanbanTaskCard(
                                      task: task,
                                      projectName: widget
                                          .projectsById[task.projectId]
                                          ?.name,
                                      onViewSubtasks: widget.onViewSubtasks,
                                      elevated: true,
                                    ),
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.4,
                                child: _KanbanTaskCard(
                                  task: task,
                                  projectName:
                                      widget.projectsById[task.projectId]?.name,
                                  onViewSubtasks: widget.onViewSubtasks,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => widget.onTapTask(task),
                                child: _KanbanTaskCard(
                                  task: task,
                                  projectName:
                                      widget.projectsById[task.projectId]?.name,
                                  onViewSubtasks: widget.onViewSubtasks,
                                ),
                              ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KanbanTaskCard extends StatelessWidget {
  const _KanbanTaskCard({
    required this.task,
    required this.projectName,
    required this.onViewSubtasks,
    this.elevated = false,
  });

  final Task task;
  final String? projectName;
  final ValueChanged<Task> onViewSubtasks;
  final bool elevated;

  bool get _isOverdue {
    if (task.completedAt != null || task.dueDate == null) return false;
    final today = DateTime.now();
    final due = task.dueDate!;
    return DateTime(
      due.year,
      due.month,
      due.day,
    ).isBefore(DateTime(today.year, today.month, today.day));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final overdue = _isOverdue;
    final checklist = task.checklist;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: overdue
            ? semantic.priorityHighContainer.withValues(alpha: 0.3)
            : theme.cardTheme.color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: overdue ? semantic.priorityHigh : colorScheme.outlineVariant,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => onViewSubtasks(task),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.account_tree_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              PriorityBadge(priority: task.priority),
            ],
          ),
          if ((task.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              task.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (task.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in task.tags.take(2))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(tag, style: theme.textTheme.labelSmall),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.dueDate == null
                          ? '—'
                          : DateFormat('dd/MM').format(task.dueDate!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: overdue
                            ? semantic.priorityHigh
                            : colorScheme.onSurfaceVariant,
                        fontWeight: overdue ? FontWeight.w500 : null,
                      ),
                    ),
                  ],
                ),
                if (projectName != null)
                  Text(
                    projectName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (checklist.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_box_outlined,
                  size: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${checklist.where((c) => c.done).length}/${checklist.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
