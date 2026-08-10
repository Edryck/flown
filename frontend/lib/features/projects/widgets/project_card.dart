import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/project.dart';
import '../../../core/theme/semantic_colors.dart';
import '../utils/project_stats.dart';

/// Card de projeto na grade — tradução fiel do card de `Projects.tsx`
/// (docs/prototype/screens/projects.md): barra de cor no topo, nome +
/// descrição, badge de status + badge "Atrasado", contagem de tasks, barra
/// de progresso, próximo prazo. Sem ações próprias — o card inteiro é
/// clicável (`onTap`) e abre `ProjectViewDialog`, que concentra Editar/
/// Remover (mesmo espírito de `TasksKanbanView`, onde o card só notifica
/// toque e quem abre o diálogo é a tela).
///
/// O badge de status não é o `StatusBadge` compartilhado (que espera um
/// status de verdade vindo do backend) — aqui é um rótulo calculado a
/// partir de `ProjectStats` (ver `project_stats.dart`), já que `Project`
/// não tem campo de status.
class ProjectCard extends StatefulWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.stats,
    required this.onTap,
  });

  final Project project;
  final ProjectStats stats;
  final VoidCallback onTap;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final project = widget.project;
    final stats = widget.stats;
    final projectColor = Color(int.parse(project.color.replaceFirst('#', '0xFF')));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: _hovering
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, color: projectColor),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if ((project.description ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  project.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: projectColor.withValues(alpha: _hovering ? 0.3 : 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.folder_outlined, color: projectColor, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      DerivedStatusBadge(stats: stats),
                      if (stats.isOverdue) ...[
                        const SizedBox(width: 8),
                        OverdueBadge(semantic: semantic),
                      ],
                      const Spacer(),
                      Text(
                        stats.taskCount == 1 ? '1 tarefa' : '${stats.taskCount} tarefas',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  if (stats.taskCount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progresso',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        Text('${stats.progress}%', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stats.progress / 100,
                        minHeight: 8,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                  if (stats.nextDueDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy').format(stats.nextDueDate!),
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class DerivedStatusBadge extends StatelessWidget {
  const DerivedStatusBadge({super.key, required this.stats});

  final ProjectStats stats;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final colorScheme = Theme.of(context).colorScheme;

    final (String label, Color fg, Color bg) = stats.taskCount == 0
        ? ('Sem tarefas', colorScheme.onSurfaceVariant, colorScheme.surfaceContainerHighest)
        : stats.isDone
            ? ('Concluído', semantic.priorityLow, semantic.priorityLowContainer)
            : ('Ativo', colorScheme.primary, colorScheme.primaryContainer);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: 12)),
    );
  }
}

class OverdueBadge extends StatelessWidget {
  const OverdueBadge({super.key, required this.semantic});

  final AppSemanticColors semantic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: semantic.priorityHighContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: semantic.priorityHigh.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 12, color: semantic.priorityHigh),
          const SizedBox(width: 4),
          Text('Atrasado', style: TextStyle(color: semantic.priorityHigh, fontWeight: FontWeight.w500, fontSize: 12)),
        ],
      ),
    );
  }
}
