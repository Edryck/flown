import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/checklist_item.dart';
import '../../../core/models/project.dart';
import '../../../core/models/project_type.dart';
import '../../../core/models/task.dart';
import '../../../core/widgets/badge_size.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../projects/providers/project_type_repository.dart';
import '../providers/task_list_controller.dart';
import '../providers/task_repository.dart';
import '../utils/task_hierarchy.dart';
import '../utils/task_status_colors.dart';
import 'task_form_dialog.dart';

/// Abre a tarefa em modo "só olhar" — complementar ao `TaskFormDialog`
/// (edição completa). O form de edição é "sujo" demais só pra dar uma
/// olhada rápida numa task — esse diálogo mostra os dados (estilo do card
/// do Modo Foco, `_FocusTaskCard`) e só
/// permite as 2 ações rápidas que fazem sentido sem abrir o form inteiro:
/// mudar o status e marcar itens do checklist. Um botão "Editar" leva pro
/// `TaskFormDialog` quando precisar mexer em mais coisa.
///
/// É também o diálogo que abre ao tocar num nó do `SubtasksGraphDialog`.
Future<void> showTaskViewDialog(BuildContext context, {required Task task}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _TaskViewDialog(taskId: task.id),
  );
}

/// `ConsumerWidget` que observa `taskListControllerProvider` e busca a task
/// pelo id (em vez de guardar a instância recebida) — assim, uma mudança de
/// status/checklist feita aqui mesmo já reflete no diálogo imediatamente,
/// sem fechar/reabrir.
class _TaskViewDialog extends ConsumerWidget {
  const _TaskViewDialog({required this.taskId});

  final String taskId;

  List<String> _availableStatusFor(
    Task task,
    List<Project> projects,
    List<ProjectType> types,
  ) {
    if (task.projectId == null) return const [];
    final project = projects.where((p) => p.id == task.projectId).firstOrNull;
    if (project == null) return const [];
    final type = types.where((t) => t.id == project.typeId).firstOrNull;
    return type?.availableStatus ?? const [];
  }

  void _toggleChecklistItem(WidgetRef ref, Task task, int index, bool done) {
    final updated = [
      for (var i = 0; i < task.checklist.length; i++)
        i == index
            ? ChecklistItem(text: task.checklist[i].text, done: done)
            : task.checklist[i],
    ];
    final progress =
        ((updated.where((c) => c.done).length / updated.length) * 100).round();
    ref
        .read(taskListControllerProvider.notifier)
        .updateTask(task.id, TaskInput(checklist: updated, progress: progress));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tasksAsync = ref.watch(taskListControllerProvider);
    final task = tasksAsync.valueOrNull
        ?.where((t) => t.id == taskId)
        .firstOrNull;

    if (task == null) {
      // A task pode ter sido excluída por outra aba/ação enquanto o
      // diálogo estava aberto — fecha sozinho em vez de mostrar tela vazia.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final projects =
        ref.watch(projectListControllerProvider).valueOrNull ??
        const <Project>[];
    final types =
        ref.watch(projectTypeListProvider).valueOrNull ?? const <ProjectType>[];
    final projectName = task.projectId == null
        ? null
        : projects.where((p) => p.id == task.projectId).firstOrNull?.name;
    final availableStatus = _availableStatusFor(task, projects, types);
    final checklist = task.checklist;
    final dueDate = effectiveDueDate(
      task,
      tasksAsync.valueOrNull ?? const <Task>[],
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  PriorityBadge(priority: task.priority, size: BadgeSize.md),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if ((task.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  task.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (projectName != null)
                      _MetaItem(label: 'Projeto', value: projectName),
                    if (dueDate != null)
                      _MetaItem(
                        label: task.parentTaskId != null
                            ? 'Vencimento (herdado)'
                            : 'Vencimento',
                        value: DateFormat('dd/MM/yyyy').format(dueDate),
                      ),
                    if ((task.estimatedTime ?? '').isNotEmpty)
                      _MetaItem(label: 'Estimado', value: task.estimatedTime!),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Status', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              availableStatus.isEmpty
                  ? Text(
                      'Sem projeto associado — não é possível mudar o status',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      key: ValueKey(task.status),
                      initialValue: availableStatus.contains(task.status)
                          ? task.status
                          : null,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        for (final status in availableStatus)
                          DropdownMenuItem(
                            value: status,
                            child: Text(statusLabelPtBr(status)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(taskListControllerProvider.notifier)
                              .updateTask(task.id, TaskInput(status: value));
                        }
                      },
                    ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progresso Geral', style: theme.textTheme.labelLarge),
                  Text(
                    '${task.progress ?? 0}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (task.progress ?? 0) / 100,
                  minHeight: 10,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              if (checklist.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Lista de Verificação', style: theme.textTheme.labelLarge),
                const SizedBox(height: 12),
                for (var i = 0; i < checklist.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _toggleChecklistItem(
                        ref,
                        task,
                        i,
                        !checklist[i].done,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: checklist[i].done,
                              onChanged: (value) => _toggleChecklistItem(
                                ref,
                                task,
                                i,
                                value ?? false,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                checklist[i].text,
                                style: checklist[i].done
                                    ? TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: colorScheme.onSurfaceVariant,
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showTaskFormDialog(context, task: task);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
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

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
