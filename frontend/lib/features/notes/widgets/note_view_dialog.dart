import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/note.dart';
import '../../../core/models/project.dart';
import '../../projects/providers/project_list_controller.dart';
import '../providers/note_list_controller.dart';
import 'note_form_dialog.dart';

/// Abre a anotação em modo "só olhar" — complementar ao `NoteFormDialog`
/// (edição), mesmo espírito de `TaskViewDialog`/`ProjectViewDialog`:
/// concentra Editar/Remover (o `NoteCard` não tem mais ações próprias além
/// de fixar) e, diferente dos outros, renderiza `content` como Markdown em
/// vez de texto cru.
Future<void> showNoteViewDialog(BuildContext context, {required Note note}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _NoteViewDialog(noteId: note.id),
  );
}

/// `ConsumerWidget` que observa `noteListControllerProvider` e busca a nota
/// pelo id (em vez de guardar a instância recebida) — mesmo motivo das
/// outras views: uma edição feita aqui mesmo já reflete no diálogo, e se a
/// nota for removida ele fecha sozinho.
class _NoteViewDialog extends ConsumerWidget {
  const _NoteViewDialog({required this.noteId});

  final String noteId;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir anotação'),
        content: Text('Excluir "${note.title}"? Ela vai pra lixeira.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(noteListControllerProvider.notifier).delete(note.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notesAsync = ref.watch(noteListControllerProvider);
    final note = notesAsync.valueOrNull
        ?.where((n) => n.id == noteId)
        .firstOrNull;

    if (note == null) {
      // A nota pode ter sido excluída (inclusive pelo botão "Excluir" deste
      // próprio diálogo) enquanto ele estava aberto.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final projects =
        ref.watch(projectListControllerProvider).valueOrNull ??
        const <Project>[];
    final projectName = note.projectId == null
        ? null
        : projects.where((p) => p.id == note.projectId).firstOrNull?.name;

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
                      note.title,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (note.isPinned) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.push_pin,
                      size: 20,
                      color: colorScheme.secondary,
                    ),
                  ],
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (projectName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        projectName,
                        style: TextStyle(
                          color: colorScheme.onSecondaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  for (final tag in note.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(tag, style: theme.textTheme.labelSmall),
                    ),
                  Text(
                    'Atualizado ${DateFormat('dd/MM/yyyy').format(note.updatedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: note.content.trim().isEmpty
                    ? Text(
                        'Sem conteúdo',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : MarkdownBody(
                        data: note.content,
                        styleSheet: MarkdownStyleSheet.fromTheme(theme)
                            .copyWith(
                              p: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                              code: theme.textTheme.bodySmall?.copyWith(
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                                fontFamily: 'monospace',
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              blockquoteDecoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _confirmDelete(context, ref, note),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: colorScheme.error,
                    ),
                    label: Text(
                      'Excluir',
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
                          showNoteFormDialog(context, note: note);
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
