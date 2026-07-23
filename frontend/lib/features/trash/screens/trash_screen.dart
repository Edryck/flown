import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/trash_list_controller.dart';

/// Tela de Lixeira — sem referência no protótipo (ele não modela soft
/// delete em lugar nenhum, ver docs/prototype/00-overview.md), desenhada do
/// zero seguindo o estilo visual do resto do app. Lista projetos/tarefas/
/// anotações com `isDeleted: true` (`GET /trash`), agrupados por tipo;
/// cada item pode ser restaurado ou excluído definitivamente, e "Esvaziar
/// lixeira" remove tudo de uma vez (`DELETE /trash/empty`).
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  Future<void> _confirmEmptyTrash(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Esvaziar lixeira?'),
        content: const Text(
          'Todos os projetos, tarefas e anotações aqui serão excluídos permanentemente. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Esvaziar lixeira')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(trashListControllerProvider.notifier).emptyTrash();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trashAsync = ref.watch(trashListControllerProvider);

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
                  Text('Lixeira', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    'Projetos, tarefas e anotações excluídos',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              trashAsync.maybeWhen(
                data: (trash) => trash.isEmpty
                    ? const SizedBox.shrink()
                    : OutlinedButton.icon(
                        onPressed: () => _confirmEmptyTrash(context, ref),
                        icon: Icon(Icons.delete_forever_outlined, size: 18, color: theme.colorScheme.error),
                        label: Text('Esvaziar lixeira', style: TextStyle(color: theme.colorScheme.error)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: theme.colorScheme.error)),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          trashAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('Erro ao carregar a lixeira: $error')),
            ),
            data: (trash) {
              if (trash.isEmpty) return _EmptyTrashState(theme: theme);

              final controller = ref.read(trashListControllerProvider.notifier);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trash.projects.isNotEmpty)
                    _TrashSection(
                      title: 'Projetos',
                      children: [
                        for (final project in trash.projects)
                          _TrashRow(
                            icon: Icons.folder_outlined,
                            title: project.name,
                            deletedAt: project.deletedAt,
                            onRestore: () => controller.restoreProject(project.id),
                            onDeleteForever: () => _confirmDeleteForever(
                              context,
                              itemName: project.name,
                              onConfirm: () => controller.permanentDeleteProject(project.id),
                            ),
                          ),
                      ],
                    ),
                  if (trash.tasks.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _TrashSection(
                      title: 'Tarefas',
                      children: [
                        for (final task in trash.tasks)
                          _TrashRow(
                            icon: Icons.check_box_outlined,
                            title: task.title,
                            deletedAt: task.deletedAt,
                            onRestore: () => controller.restoreTask(task.id),
                            onDeleteForever: () => _confirmDeleteForever(
                              context,
                              itemName: task.title,
                              onConfirm: () => controller.permanentDeleteTask(task.id),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (trash.notes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _TrashSection(
                      title: 'Anotações',
                      children: [
                        for (final note in trash.notes)
                          _TrashRow(
                            icon: Icons.description_outlined,
                            title: note.title,
                            deletedAt: note.deletedAt,
                            onRestore: () => controller.restoreNote(note.id),
                            onDeleteForever: () => _confirmDeleteForever(
                              context,
                              itemName: note.title,
                              onConfirm: () => controller.permanentDeleteNote(note.id),
                            ),
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

  Future<void> _confirmDeleteForever(
    BuildContext context, {
    required String itemName,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir definitivamente?'),
        content: Text('"$itemName" será excluído permanentemente. Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed == true) await onConfirm();
  }
}

class _TrashSection extends StatelessWidget {
  const _TrashSection({required this.title, required this.children});

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

class _TrashRow extends StatelessWidget {
  const _TrashRow({
    required this.icon,
    required this.title,
    required this.deletedAt,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final IconData icon;
  final String title;
  final DateTime? deletedAt;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
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
                  deletedAt == null ? 'Excluído recentemente' : 'Excluído em ${DateFormat('dd/MM/yyyy').format(deletedAt!)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Restaurar'),
          ),
          IconButton(
            tooltip: 'Excluir definitivamente',
            onPressed: onDeleteForever,
            icon: Icon(Icons.delete_forever_outlined, size: 18, color: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrashState extends StatelessWidget {
  const _EmptyTrashState({required this.theme});

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
              child: Icon(Icons.delete_outline, size: 28, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              'A lixeira está vazia',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
