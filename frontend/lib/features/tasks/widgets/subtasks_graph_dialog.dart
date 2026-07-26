import 'package:flutter/material.dart';
import 'package:flutter_graph_view/flutter_graph_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task.dart';
import '../providers/task_list_controller.dart';
import '../utils/task_hierarchy.dart';
import 'task_form_dialog.dart';
import 'task_view_dialog.dart';

/// Abre o grafo de subtarefas de uma task — nó central (a task) ligado a um
/// nó por subtarefa direta. Só 1 nível de propósito (ver
/// `task_hierarchy.dart`). Visual "estilo Obsidian" (grafo de força, nós se
/// repelindo/atraindo), sem referência no protótipo.
Future<void> showSubtasksGraphDialog(
  BuildContext context, {
  required Task task,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SubtasksGraphDialog(taskId: task.id),
  );
}

class _SubtasksGraphDialog extends ConsumerWidget {
  const _SubtasksGraphDialog({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasks =
        ref.watch(taskListControllerProvider).valueOrNull ?? const <Task>[];
    final parent = tasks.where((t) => t.id == taskId).firstOrNull;

    if (parent == null) {
      // A task pode ter sido excluída enquanto o diálogo estava aberto.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final subtasks = subtasksOf(parent, tasks);

    final data = {
      'vertexes': <Map>[
        {
          'id': parent.id,
          'tag': 'root',
          'data': {'title': parent.title},
        },
        for (final s in subtasks)
          {
            'id': s.id,
            'tag': 'subtask',
            'data': {'title': s.title},
          },
      ],
      'edges': <Map>[
        for (final s in subtasks)
          {
            'srcId': parent.id,
            'dstId': s.id,
            'edgeName': 'subtask',
            'ranking': 0,
          },
      ],
    };

    void openTaskView(String id) {
      final tapped = tasks.where((t) => t.id == id).firstOrNull;
      if (tapped != null) showTaskViewDialog(context, task: tapped);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subtarefas',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          parent.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: subtasks.isEmpty
                      ? _GraphEmptyState(rootTitle: parent.title)
                      : FlutterGraphWidget(
                          key: ValueKey(taskId),
                          data: data,
                          algorithm: ForceDirected(
                            decorators: [
                              CoulombDecorator(),
                              HookeDecorator(),
                              ForceDecorator(),
                              ForceMotionDecorator(),
                              TimeCounterDecorator(),
                            ],
                          ),
                          convertor: MapConvertor(),
                          options: Options()
                            ..textGetter = ((vertex) =>
                                (vertex.data['title'] as String?) ?? '')
                            ..onVertexTapUp = ((vertex, _) =>
                                openTaskView(vertex.id.toString()))
                            // Fundo segue o tema do app (claro/escuro) em vez
                            // de escuro fixo — antes o texto branco do rótulo
                            // ficava ilegível no tema claro.
                            ..backgroundBuilder = ((context) => Container(
                              color: theme.colorScheme.surfaceContainerLow,
                            ))
                            ..graphStyle = (GraphStyle()
                              ..tagColor = {
                                'root': const Color(0xFF7BA3C7),
                                'subtask': const Color(0xFF4A9E99),
                              }
                              // O pacote já desenha o rótulo acima do nó
                              // (vertex_text_renderer_impl.dart) — o texto
                              // sozinho ficava difícil de reconhecer quando
                              // nós próximos se sobrepunham; o
                              // `backgroundColor` aqui dá um "chip" atrás de
                              // cada rótulo, então ele se destaca do fundo e
                              // dos outros nós/arestas por trás.
                              ..vertexTextStyleGetter = (vertex, shape) =>
                                  TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    backgroundColor: theme
                                        .colorScheme
                                        .surfaceContainerLow
                                        .withValues(alpha: 0.9),
                                  )),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    subtasks.isEmpty
                        ? 'Nenhuma subtarefa ainda'
                        : '${subtasks.length} subtarefa(s)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => showTaskFormDialog(
                      context,
                      initialParentTaskId: parent.id,
                      initialProjectId: parent.projectId,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar Subtarefa'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphEmptyState extends StatelessWidget {
  const _GraphEmptyState({required this.rootTitle});

  final String rootTitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerLow,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 40,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhuma subtarefa ainda',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Adicione a primeira subtarefa de "$rootTitle" abaixo',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 12,
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
