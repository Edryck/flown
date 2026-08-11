import 'package:flutter/material.dart';

import '../../../core/models/task.dart';

/// Resultado de `showTaskPickerDialog` — `null` (a `Future` inteira) quando
/// o usuário só fechou o diálogo sem escolher nada. `TaskPickerResult.auto`
/// e `.task` precisam ser distinguíveis de "cancelou" (por isso não é só um
/// `Task?`: um `Task?` não teria como diferenciar "cancelou" de "escolheu
/// Automático", os dois pareceriam `null`).
class TaskPickerResult {
  const TaskPickerResult.auto() : task = null;
  const TaskPickerResult.pick(this.task);

  /// `null` quando o resultado é "Automático" (volta pra regra padrão de
  /// `_pickFocusTask`); senão, a task escolhida manualmente.
  final Task? task;

  bool get isAuto => task == null;
}

/// Diálogo de escolha manual da task em foco (`focus_screen.dart`) — lista
/// tasks de nível superior não concluídas, com busca simples por título, e
/// uma opção "Automático" pra voltar à regra padrão (maior prioridade entre
/// as "Em Andamento").
Future<TaskPickerResult?> showTaskPickerDialog(
  BuildContext context, {
  required List<Task> tasks,
}) {
  return showDialog<TaskPickerResult>(
    context: context,
    builder: (context) => _TaskPickerDialog(tasks: tasks),
  );
}

class _TaskPickerDialog extends StatefulWidget {
  const _TaskPickerDialog({required this.tasks});

  final List<Task> tasks;

  @override
  State<_TaskPickerDialog> createState() => _TaskPickerDialogState();
}

class _TaskPickerDialogState extends State<_TaskPickerDialog> {
  static const _doneStatus = 'Done';

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pending = widget.tasks
        .where((t) => t.status != _doneStatus)
        .toList();
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? pending
        : pending
              .where((t) => t.title.toLowerCase().contains(query))
              .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Escolher tarefa',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Buscar tarefas...',
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome),
                title: const Text('Automático'),
                subtitle: const Text(
                  'Maior prioridade entre as "Em Andamento"',
                ),
                onTap: () => Navigator.of(
                  context,
                ).pop(const TaskPickerResult.auto()),
              ),
              const Divider(),
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Nenhuma tarefa encontrada',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final task = filtered[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(task.status),
                            onTap: () => Navigator.of(
                              context,
                            ).pop(TaskPickerResult.pick(task)),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
