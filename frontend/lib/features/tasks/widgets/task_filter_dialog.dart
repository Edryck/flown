import 'package:flutter/material.dart';

import '../../../core/models/project.dart';
import '../../../core/models/task_priority.dart';
import '../../../core/widgets/priority_badge.dart';
import '../utils/task_status_colors.dart';

/// Seleção atual de filtros da tela de Tasks — conjunto vazio em
/// `statuses`/`priorities`/`projectIds` significa "sem filtro" (mostra
/// tudo), não "nada passa".
class TaskFilterSelection {
  const TaskFilterSelection({
    this.statuses = const {},
    this.priorities = const {},
    this.projectIds = const {},
    this.onlyOverdue = false,
  });

  final Set<String> statuses;
  final Set<TaskPriority> priorities;
  final Set<String> projectIds;
  final bool onlyOverdue;

  int get activeCount =>
      (statuses.isNotEmpty ? 1 : 0) +
      (priorities.isNotEmpty ? 1 : 0) +
      (projectIds.isNotEmpty ? 1 : 0) +
      (onlyOverdue ? 1 : 0);
}

/// Abre o diálogo de filtro da tela de Tasks (modo lista) — botão "Filtrar"
/// era decorativo tanto no protótipo (`Tasks.tsx`, sem `onClick`) quanto na
/// primeira tradução Flutter. Como diálogo (não dropdown) porque
/// status/prioridade são seleção múltipla — um `PopupMenuButton` fecha a
/// cada item marcado, o que obrigaria reabrir o menu por filtro.
Future<TaskFilterSelection?> showTaskFilterDialog(
  BuildContext context, {
  required List<String> statusOptions,
  required List<Project> projects,
  required TaskFilterSelection initial,
}) {
  return showDialog<TaskFilterSelection>(
    context: context,
    builder: (context) => _TaskFilterDialog(
      statusOptions: statusOptions,
      projects: projects,
      initial: initial,
    ),
  );
}

class _TaskFilterDialog extends StatefulWidget {
  const _TaskFilterDialog({
    required this.statusOptions,
    required this.projects,
    required this.initial,
  });

  final List<String> statusOptions;
  final List<Project> projects;
  final TaskFilterSelection initial;

  @override
  State<_TaskFilterDialog> createState() => _TaskFilterDialogState();
}

class _TaskFilterDialogState extends State<_TaskFilterDialog> {
  late Set<String> _statuses = {...widget.initial.statuses};
  late Set<TaskPriority> _priorities = {...widget.initial.priorities};
  late Set<String> _projectIds = {...widget.initial.projectIds};
  late bool _onlyOverdue = widget.initial.onlyOverdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Filtrar tarefas'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Status', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in widget.statusOptions)
                    FilterChip(
                      label: Text(statusLabelPtBr(status)),
                      selected: _statuses.contains(status),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _statuses.add(status);
                        } else {
                          _statuses.remove(status);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Prioridade', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final priority in TaskPriority.values)
                    FilterChip(
                      label: Text(PriorityBadge.labels[priority]!),
                      selected: _priorities.contains(priority),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _priorities.add(priority);
                        } else {
                          _priorities.remove(priority);
                        }
                      }),
                    ),
                ],
              ),
              if (widget.projects.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Projeto', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final project in widget.projects)
                      FilterChip(
                        label: Text(project.name),
                        selected: _projectIds.contains(project.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _projectIds.add(project.id);
                          } else {
                            _projectIds.remove(project.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _onlyOverdue,
                onChanged: (value) =>
                    setState(() => _onlyOverdue = value ?? false),
                title: const Text('Somente atrasadas'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _statuses = {};
            _priorities = {};
            _projectIds = {};
            _onlyOverdue = false;
          }),
          child: const Text('Limpar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            TaskFilterSelection(
              statuses: _statuses,
              priorities: _priorities,
              projectIds: _projectIds,
              onlyOverdue: _onlyOverdue,
            ),
          ),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
