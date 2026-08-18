import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project.dart';
import '../../../core/models/project_type.dart';
import '../../../core/models/task.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/form_section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../tasks/providers/task_list_controller.dart';
import '../../tasks/utils/task_hierarchy.dart';
import '../../tasks/utils/task_status_colors.dart';
import '../../tasks/widgets/task_form_dialog.dart';
import '../../tasks/widgets/task_view_dialog.dart';
import '../providers/project_list_controller.dart';
import '../providers/project_type_repository.dart';
import '../utils/project_stats.dart';
import 'project_card.dart';
import 'project_form_dialog.dart';

/// Abre o projeto em modo "só olhar" — complementar ao `ProjectFormDialog`
/// (edição), mesmo espírito do `TaskViewDialog`: mostra os dados (aqui,
/// derivados de `ProjectStats` — o mesmo cálculo que já alimenta o
/// `ProjectCard`) mais a lista de tarefas do projeto, e concentra Editar/
/// Remover, já que o `ProjectCard` não tem mais ações próprias.
Future<void> showProjectViewDialog(
  BuildContext context, {
  required Project project,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ProjectViewDialog(projectId: project.id),
  );
}

/// `ConsumerWidget` que observa `projectListControllerProvider` e busca o
/// projeto pelo id (em vez de guardar a instância recebida) — assim, uma
/// edição feita aqui mesmo (ou em outra tela) já reflete no diálogo
/// imediatamente, sem fechar/reabrir (mesmo motivo do `TaskViewDialog`).
class _ProjectViewDialog extends ConsumerWidget {
  const _ProjectViewDialog({required this.projectId});

  final String projectId;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover projeto?'),
        content: Text(
          'Tem certeza que deseja remover o projeto "${project.name}"? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(projectListControllerProvider.notifier).delete(project.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final projectsAsync = ref.watch(projectListControllerProvider);
    final project = projectsAsync.valueOrNull
        ?.where((p) => p.id == projectId)
        .firstOrNull;

    if (project == null) {
      // O projeto pode ter sido removido (inclusive pelo botão "Remover"
      // deste próprio diálogo) enquanto ele estava aberto.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final allTasks =
        ref.watch(taskListControllerProvider).valueOrNull ?? const <Task>[];
    final types =
        ref.watch(projectTypeListProvider).valueOrNull ?? const <ProjectType>[];
    final tasks = allTasks.where((t) => t.projectId == project.id).toList();
    final stats = computeProjectStats(tasks);
    final statusOrder = resolveStatusOrder(types, allTasks);
    final projectColor = Color(
      int.parse(project.color.replaceFirst('#', '0xFF')),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 28,
                    margin: const EdgeInsets.only(top: 4, right: 12),
                    decoration: BoxDecoration(
                      color: projectColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if ((project.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  project.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  DerivedStatusBadge(stats: stats),
                  if (stats.isOverdue) ...[
                    const SizedBox(width: 8),
                    OverdueBadge(semantic: context.semanticColors),
                  ],
                  const Spacer(),
                  Text(
                    stats.taskCount == 1
                        ? '1 tarefa'
                        : '${stats.taskCount} tarefas',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (stats.taskCount > 0 || stats.nextDueDate != null) ...[
                const SizedBox(height: 20),
                FormSectionCard(
                  title: 'Progresso',
                  icon: Icons.donut_large_outlined,
                  description: 'O quanto do projeto já foi concluído.',
                  children: [
                    if (stats.taskCount > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tarefas concluídas', style: theme.textTheme.labelLarge),
                          Text(
                            '${stats.progress}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.sharp),
                        child: LinearProgressIndicator(
                          value: stats.progress / 100,
                          minHeight: 10,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                    if (stats.nextDueDate != null) ...[
                      if (stats.taskCount > 0) const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Próximo prazo: ${DateFormat('dd/MM/yyyy').format(stats.nextDueDate!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 20),
              FormSectionCard(
                title: 'Tarefas (${tasks.length})',
                icon: Icons.folder_outlined,
                description: 'Todas as tarefas desse projeto, com as subtarefas aninhadas.',
                children: [
                  if (tasks.isEmpty)
                    Text(
                      'Nenhuma tarefa neste projeto ainda',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    _ProjectTasksTree(tasks: tasks, statusOrder: statusOrder),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => showTaskFormDialog(
                      context,
                      initialProjectId: project.id,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nova Tarefa'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _confirmDelete(context, ref, project),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: colorScheme.error,
                    ),
                    label: Text(
                      'Remover',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fechar'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          showProjectFormDialog(context, project: project);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista de tasks do projeto com as subtasks de cada uma aninhadas embaixo,
/// recolhível por task (padrão: tudo expandido). Só 1 nível de subtasks —
/// mesma regra de `task_hierarchy.dart` (subtarefa não tem subtarefa).
class _ProjectTasksTree extends StatefulWidget {
  const _ProjectTasksTree({required this.tasks, required this.statusOrder});

  final List<Task> tasks;
  final List<String> statusOrder;

  @override
  State<_ProjectTasksTree> createState() => _ProjectTasksTreeState();
}

class _ProjectTasksTreeState extends State<_ProjectTasksTree> {
  final Set<String> _collapsedTaskIds = {};

  int _statusColorIndex(String status) => widget.statusOrder.isEmpty
      ? 0
      : widget.statusOrder.indexOf(status).clamp(0, widget.statusOrder.length - 1);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final roots = topLevelTasks(widget.tasks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final task in roots) ...[
          _buildTaskRow(context, colorScheme, task),
          if (!_collapsedTaskIds.contains(task.id))
            ..._buildSubtaskRows(context, colorScheme, task),
        ],
      ],
    );
  }

  List<Widget> _buildSubtaskRows(
    BuildContext context,
    ColorScheme colorScheme,
    Task task,
  ) {
    final subtasks = subtasksOf(task, widget.tasks);
    return [
      for (var i = 0; i < subtasks.length; i++)
        _buildSubtaskRow(
          context,
          colorScheme,
          subtasks[i],
          isLast: i == subtasks.length - 1,
        ),
    ];
  }

  Widget _buildTaskRow(BuildContext context, ColorScheme colorScheme, Task task) {
    final hasSubtasks = subtasksOf(task, widget.tasks).isNotEmpty;
    final collapsed = _collapsedTaskIds.contains(task.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 40,
            child: hasSubtasks
                ? InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() {
                      if (collapsed) {
                        _collapsedTaskIds.remove(task.id);
                      } else {
                        _collapsedTaskIds.add(task.id);
                      }
                    }),
                    child: AnimatedRotation(
                      turns: collapsed ? 0 : 0.25,
                      duration: const Duration(milliseconds: 150),
                      child: const Icon(Icons.chevron_right, size: 18),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.card),
              onTap: () => showTaskViewDialog(context, task: task),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(task.title, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      label: statusLabelPtBr(task.status),
                      colorIndex: _statusColorIndex(task.status),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtaskRow(
    BuildContext context,
    ColorScheme colorScheme,
    Task subtask, {
    required bool isLast,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TreeConnector(isLast: isLast),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.card),
                onTap: () => showTaskViewDialog(context, task: subtask),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtask.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: statusLabelPtBr(subtask.status),
                        colorIndex: _statusColorIndex(subtask.status),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Conector visual "parecido com árvore" entre a task-mãe e suas subtasks —
/// um traço vertical + um cotovelo horizontal desenhados via `CustomPainter`
/// (evoca `├`/`└` sem usar os caracteres literais). `isLast` corta o traço
/// vertical na metade (equivalente ao `└`); senão o traço desce inteiro
/// (equivalente ao `├`, continuando pra próxima subtask).
class _TreeConnector extends StatelessWidget {
  const _TreeConnector({required this.isLast});

  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: CustomPaint(
        painter: _TreeConnectorPainter(
          isLast: isLast,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _TreeConnectorPainter extends CustomPainter {
  _TreeConnectorPainter({required this.isLast, required this.color});

  final bool isLast;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final midX = size.width / 2;
    final midY = size.height / 2;
    canvas.drawLine(
      Offset(midX, 0),
      Offset(midX, isLast ? midY : size.height),
      paint,
    );
    canvas.drawLine(Offset(midX, midY), Offset(size.width, midY), paint);
  }

  @override
  bool shouldRepaint(covariant _TreeConnectorPainter oldDelegate) =>
      oldDelegate.isLast != isLast || oldDelegate.color != color;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
