import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../notes/widgets/note_view_dialog.dart';
import '../../projects/widgets/project_view_dialog.dart';
import '../../tasks/widgets/task_view_dialog.dart';
import '../providers/archive_list_controller.dart';

/// Tela de Arquivo — mesmo esqueleto de `TrashScreen`
/// (`features/trash/screens/trash_screen.dart`), mas sem exclusão: item
/// arquivado só volta pra lista ativa ("Desarquivar"), nunca é apagado por
/// aqui. Lista projetos/tarefas/anotações com `isArchived: true`
/// (`GET /archive`), agrupados por tipo.
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final archiveAsync = ref.watch(archiveListControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Arquivo', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
          Text(
            'Projetos, tarefas e anotações arquivados',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          archiveAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('Erro ao carregar o arquivo: $error')),
            ),
            data: (archive) {
              if (archive.isEmpty) return _EmptyArchiveState(theme: theme);

              final controller = ref.read(archiveListControllerProvider.notifier);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (archive.projects.isNotEmpty)
                    _ArchiveSection(
                      title: 'Projetos',
                      children: [
                        for (final project in archive.projects)
                          _ArchiveRow(
                            icon: Icons.folder_outlined,
                            title: project.name,
                            archivedAt: project.archivedAt,
                            onTap: () => showProjectViewDialog(context, project: project),
                            onUnarchive: () => controller.unarchiveProject(project.id),
                          ),
                      ],
                    ),
                  if (archive.tasks.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _ArchiveSection(
                      title: 'Tarefas',
                      children: [
                        for (final task in archive.tasks)
                          _ArchiveRow(
                            icon: Icons.check_box_outlined,
                            title: task.title,
                            archivedAt: task.archivedAt,
                            onTap: () => showTaskViewDialog(context, task: task),
                            onUnarchive: () => controller.unarchiveTask(task.id),
                          ),
                      ],
                    ),
                  ],
                  if (archive.notes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _ArchiveSection(
                      title: 'Anotações',
                      children: [
                        for (final note in archive.notes)
                          _ArchiveRow(
                            icon: Icons.description_outlined,
                            title: note.title,
                            archivedAt: note.archivedAt,
                            onTap: () => showNoteViewDialog(context, note: note),
                            onUnarchive: () => controller.unarchiveNote(note.id),
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ArchiveSection extends StatelessWidget {
  const _ArchiveSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text('$title (${children.length})', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({
    required this.icon,
    required this.title,
    required this.archivedAt,
    required this.onTap,
    required this.onUnarchive,
  });

  final IconData icon;
  final String title;
  final DateTime? archivedAt;
  final VoidCallback onTap;
  final VoidCallback onUnarchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    archivedAt == null ? 'Arquivado recentemente' : 'Arquivado em ${DateFormat('dd/MM/yyyy').format(archivedAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onUnarchive,
              icon: const Icon(Icons.unarchive_outlined, size: 16),
              label: const Text('Desarquivar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyArchiveState extends StatelessWidget {
  const _EmptyArchiveState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
              child: Icon(Icons.archive_outlined, size: 28, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              'O arquivo está vazio',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
