import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/note.dart';

/// Card de anotação — tradução fiel do card de `Notes.tsx`
/// (docs/prototype/screens/notes.md): título, conteúdo truncado em 3
/// linhas, badge do projeto (se houver), tags, data de atualização e ações
/// de editar/excluir — sempre visíveis (diferente do `ProjectCard`, que só
/// revela ações no hover; o protótipo de Notes não faz isso).
///
/// O ícone de fixar no canto (visível só quando `isPinned`) é fiel ao
/// protótipo; o botão de fixar/desafixar no rodapé é um acréscimo — o
/// protótipo nunca dá nenhuma forma de alterar `pinned`, só lê do mock.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.projectName,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePinned,
  });

  final Note note;
  final String? projectName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (note.isPinned) ...[
                const SizedBox(width: 8),
                Icon(Icons.push_pin, size: 16, color: colorScheme.secondary),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (projectName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  projectName!,
                  style: TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          if (note.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in note.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(tag, style: theme.textTheme.labelSmall),
                    ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: colorScheme.outlineVariant))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Atualizado ${DateFormat('dd/MM/yyyy').format(note.updatedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontSize: 11),
                  ),
                ),
                IconButton(
                  tooltip: note.isPinned ? 'Desafixar' : 'Fixar',
                  onPressed: onTogglePinned,
                  icon: Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, size: 16, color: colorScheme.error),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
