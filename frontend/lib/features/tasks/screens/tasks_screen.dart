import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../projects/providers/project_type_repository.dart';
import '../providers/task_list_controller.dart';
import '../utils/task_status_colors.dart';
import '../widgets/task_form_dialog.dart';
import '../widgets/tasks_calendar_view.dart';
import '../widgets/tasks_kanban_view.dart';
import '../widgets/tasks_table_view.dart';

enum _TasksView { table, kanban, calendar }

/// Tela central de gerenciamento de tarefas — tradução fiel de Tasks.tsx
/// (docs/prototype/screens/tasks.md): cabeçalho, barra de ferramentas
/// (troca de view + busca + Filtrar/Ordenar decorativos) e delega o
/// conteúdo pra uma das 3 views. Dados vêm do backend real
/// (`TaskListController`), não do mock — a busca continua client-side
/// (mesmo padrão do protótipo), só a fonte da lista mudou.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _TasksView _view = _TasksView.table;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Task> _filter(List<Task> tasks, Map<String, String> projectNamesById) {
    if (_searchQuery.isEmpty) return tasks;
    final query = _searchQuery.toLowerCase();
    return tasks.where((task) {
      final projectName = (projectNamesById[task.projectId] ?? '').toLowerCase();
      return task.title.toLowerCase().contains(query) ||
          (task.description ?? '').toLowerCase().contains(query) ||
          projectName.contains(query);
    }).toList();
  }

  Future<void> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir tarefa'),
        content: Text('Excluir "${task.title}"? Ela vai pra lixeira.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(taskListControllerProvider.notifier).delete(task.id);
    }
  }

  void _edit(Task task) => showTaskFormDialog(context, task: task);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskListAsync = ref.watch(taskListControllerProvider);
    final projectListAsync = ref.watch(projectListControllerProvider);
    final projectTypeListAsync = ref.watch(projectTypeListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tarefas', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    'Gerencie e rastreie suas tarefas',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => showTaskFormDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Criar Tarefa'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                _ViewSwitcher(
                  view: _view,
                  onChanged: (view) => setState(() => _view = view),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 320,
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: 'Pesquisar tarefas...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list, size: 16),
                  label: const Text('Filtrar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.sort, size: 16),
                  label: const Text('Ordenar'),
                ),
              ],
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
            data: (tasks) {
              final projects = projectListAsync.valueOrNull ?? const [];
              final projectsById = {for (final p in projects) p.id: p};
              final projectNamesById = {for (final p in projects) p.id: p.name};
              final filtered = _filter(tasks, projectNamesById);
              final statusOrder = resolveStatusOrder(projectTypeListAsync.valueOrNull ?? const [], tasks);

              return switch (_view) {
                _TasksView.table => TasksTableView(
                    tasks: filtered,
                    projectsById: projectsById,
                    statusOrder: statusOrder,
                    onEdit: _edit,
                    onDelete: _confirmDelete,
                  ),
                _TasksView.kanban => TasksKanbanView(
                    tasks: filtered,
                    projectsById: projectsById,
                    statusOrder: statusOrder,
                    onMove: (taskId, newStatus) =>
                        ref.read(taskListControllerProvider.notifier).updateStatus(taskId, newStatus),
                    onTapTask: _edit,
                  ),
                _TasksView.calendar => TasksCalendarView(tasks: tasks, onTapTask: _edit),
              };
            },
          ),
        ],
      ),
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.view, required this.onChanged});

  final _TasksView view;
  final ValueChanged<_TasksView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ViewButton(
          icon: Icons.view_list_outlined,
          label: 'Tabela',
          selected: view == _TasksView.table,
          onTap: () => onChanged(_TasksView.table),
        ),
        _ViewButton(
          icon: Icons.grid_view_outlined,
          label: 'Kanban',
          selected: view == _TasksView.kanban,
          onTap: () => onChanged(_TasksView.kanban),
        ),
        _ViewButton(
          icon: Icons.calendar_today_outlined,
          label: 'Calendário',
          selected: view == _TasksView.calendar,
          onTap: () => onChanged(_TasksView.calendar),
        ),
      ],
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: selected
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
            )
          : TextButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
              label: Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
            ),
    );
  }
}
