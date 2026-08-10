import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project.dart';
import '../../../core/models/project_type.dart';
import '../../../core/models/task.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../../tasks/providers/task_list_controller.dart';
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
              if (stats.taskCount > 0) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progresso', style: theme.textTheme.labelLarge),
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
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: stats.progress / 100,
                    minHeight: 10,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
              if (stats.nextDueDate != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd/MM/yyyy').format(stats.nextDueDate!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tarefas (${tasks.length})',
                    style: theme.textTheme.labelLarge,
                  ),
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
              const SizedBox(height: 4),
              if (tasks.isEmpty)
                Text(
                  'Nenhuma tarefa neste projeto ainda',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                for (final task in tasks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => showTaskViewDialog(context, task: task),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(
                              label: statusLabelPtBr(task.status),
                              colorIndex: statusOrder.isEmpty
                                  ? 0
                                  : statusOrder
                                      .indexOf(task.status)
                                      .clamp(0, statusOrder.length - 1),
                            ),
                          ],
                        ),
                      ),
                    ),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
