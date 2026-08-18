import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project.dart';
import '../../../core/models/task.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../../core/widgets/status_badge.dart';
import '../utils/task_status_colors.dart';

/// Tabela densa de tasks — baseada em TasksTableView.tsx
/// (docs/prototype/components/tasks-table-view.md), mas sem o checkbox de
/// seleção do protótipo: a seleção não acionava nenhuma ação em lote (sem
/// callback pra fora do widget), só ocupava espaço. Colunas: nome +
/// descrição, projeto, prioridade, status, prazo, barra de progresso e menu
/// de ações por linha. Linhas vencidas ganham destaque visual.
///
/// Usa `Table` (não `DataTable`) de propósito: `DataTable` dimensiona cada
/// coluna só pelo conteúdo e não estica pra preencher a largura disponível
/// — mesmo com o container pai em `width: double.infinity`, a tabela em si
/// (e o conteúdo das colunas) ficava menor que o fundo. `Table` com
/// `FlexColumnWidth` nas colunas "Nome"/"Projeto"/"Progresso" faz o
/// conteúdo esticar de verdade junto com o fundo.
///
/// Diferenças da fonte de dados em relação ao protótipo (mock):
///   - `isOverdue` usa `task.completedAt == null` em vez de
///     `status !== 'done'` — o backend real não tem um valor de status fixo
///     pra "concluído" (é dinâmico por `ProjectType`), mas sempre grava
///     `completedAt` quando a task é concluída (log 09 do backend);
///   - `progress`/`dueDate` são nullable no modelo real (o mock sempre
///     tinha valor) — tratados como "sem progresso"/"sem prazo" aqui;
///   - nome do projeto vem de `projectsById[task.projectId]`, já que o
///     backend usa `projectId` (FK), não um campo de texto livre.
class TasksTableView extends StatefulWidget {
  const TasksTableView({
    super.key,
    required this.tasks,
    required this.projectsById,
    required this.statusOrder,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onViewSubtasks,
  });

  final List<Task> tasks;
  final Map<String, Project> projectsById;
  final List<String> statusOrder;

  /// Clique na linha (fora do menu de ações) — abre a tarefa em modo
  /// visualização (`TaskViewDialog`), não o form de edição completo.
  final ValueChanged<Task> onView;
  final ValueChanged<Task> onEdit;
  final ValueChanged<Task> onDelete;
  final ValueChanged<Task> onViewSubtasks;

  @override
  State<TasksTableView> createState() => _TasksTableViewState();
}

class _TasksTableViewState extends State<TasksTableView> {
  static const _columnWidths = <int, TableColumnWidth>{
    0: FlexColumnWidth(3),
    1: FlexColumnWidth(1.3),
    2: FixedColumnWidth(96),
    3: FixedColumnWidth(140),
    4: FixedColumnWidth(100),
    5: FlexColumnWidth(1.6),
    6: FixedColumnWidth(96),
  };

  bool _isOverdue(Task task) {
    if (task.completedAt != null || task.dueDate == null) return false;
    final today = DateTime.now();
    final dueDate = task.dueDate!;
    return DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    ).isBefore(DateTime(today.year, today.month, today.day));
  }

  Widget _cell(
    Widget child, {
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 12,
    ),
    VoidCallback? onTap,
  }) {
    final content = Padding(padding: padding, child: child);
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      // `TableRowInkWell` (não `InkWell` puro) de propósito — ele calcula o
      // retângulo da linha inteira dentro do `Table` ancestral, então o
      // splash cobre a linha toda mesmo com cada célula sendo um
      // `TableRowInkWell` independente (mesmo padrão usado pelo `DataTable`
      // do próprio Flutter).
      child: onTap == null
          ? content
          : TableRowInkWell(onTap: onTap, child: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.tasks.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(vertical: 48),
        alignment: Alignment.center,
        child: Text(
          'Nenhuma tarefa encontrada',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    const headerLabelStyle = TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 13,
    );

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Table(
        columnWidths: _columnWidths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            // Blend de `onSurface` sobre a cor do card (não um tom fixo de
            // `ColorScheme`) de propósito - garante contraste em qualquer
            // dos 6 presets: `onSurface` é sempre escolhido pra contrastar
            // com a superfície, então misturar um pouco dele sempre escurece
            // (tema claro) ou clareia (tema escuro) o cabeçalho em relação
            // ao card, nunca fica parecido demais como com um tom fixo.
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                colorScheme.onSurface.withValues(alpha: 0.06),
                theme.cardTheme.color ?? colorScheme.surface,
              ),
            ),
            children: [
              _cell(const Text('Nome da Tarefa', style: headerLabelStyle)),
              _cell(const Text('Projeto', style: headerLabelStyle)),
              _cell(const Text('Prioridade', style: headerLabelStyle)),
              _cell(const Text('Status', style: headerLabelStyle)),
              _cell(const Text('Prazo', style: headerLabelStyle)),
              _cell(const Text('Progresso', style: headerLabelStyle)),
              _cell(const SizedBox.shrink()),
            ],
          ),
          for (final task in widget.tasks)
            TableRow(
              decoration: BoxDecoration(
                color: _isOverdue(task)
                    ? context.semanticColors.priorityHighContainer.withValues(
                        alpha: 0.3,
                      )
                    : null,
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              children: [
                _cell(
                  onTap: () => widget.onView(task),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          decoration: task.completedAt != null
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.completedAt != null
                              ? colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                      if ((task.description ?? '').isNotEmpty)
                        Text(
                          task.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                _cell(
                  onTap: () => widget.onView(task),
                  Text(
                    widget.projectsById[task.projectId]?.name ?? '—',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _cell(
                  onTap: () => widget.onView(task),
                  PriorityBadge(priority: task.priority),
                ),
                _cell(
                  onTap: () => widget.onView(task),
                  StatusBadge(
                    label: statusLabelPtBr(task.status),
                    colorIndex: widget.statusOrder
                        .indexOf(task.status)
                        .clamp(0, widget.statusOrder.length - 1),
                  ),
                ),
                _cell(
                  onTap: () => widget.onView(task),
                  Text(
                    task.dueDate == null
                        ? '—'
                        : DateFormat('dd/MM/yyyy').format(task.dueDate!),
                    style: _isOverdue(task)
                        ? TextStyle(
                            color: context.semanticColors.priorityHigh,
                            fontWeight: FontWeight.w500,
                          )
                        : null,
                  ),
                ),
                _cell(
                  onTap: () => widget.onView(task),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (task.progress ?? 0) / 100,
                            minHeight: 6,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${task.progress ?? 0}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _cell(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => widget.onViewSubtasks(task),
                        icon: const Icon(Icons.account_tree_outlined, size: 18),
                        tooltip: 'Ver subtarefas',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<_RowAction>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        padding: EdgeInsets.zero,
                        onSelected: (action) {
                          switch (action) {
                            case _RowAction.edit:
                              widget.onEdit(task);
                            case _RowAction.delete:
                              widget.onDelete(task);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: _RowAction.edit,
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 16),
                                SizedBox(width: 8),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _RowAction.delete,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Excluir',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _RowAction { edit, delete }
