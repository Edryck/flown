import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/models/note.dart';
import '../../../core/models/note_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Card de anotação — tradução fiel do card de `Notes.tsx`
/// (docs/prototype/screens/notes.md): título, conteúdo truncado em 3
/// linhas, badge do projeto (se houver), tags e data de atualização. Sem
/// ações de editar/excluir próprias — o card inteiro é clicável (`onTap`) e
/// abre `NoteViewDialog`, que concentra Editar/Excluir (mesmo espírito de
/// `ProjectCard`).
///
/// O ícone de fixar no canto (visível só quando `isPinned`) é fiel ao
/// protótipo; o botão de fixar/desafixar no rodapé é um acréscimo — o
/// protótipo nunca dá nenhuma forma de alterar `pinned`, só lê do mock. Fica
/// fora do `onTap` do card (ação rápida, não precisa abrir o diálogo).
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.projectName,
    required this.onTap,
    required this.onTogglePinned,
  });

  final Note note;
  final String? projectName;
  final VoidCallback onTap;
  final VoidCallback onTogglePinned;

  // Texto sempre escuro, independente do tema do app (claro/escuro) - um
  // post-it de papel não muda de cor com a luz do ambiente. As 7 cores da
  // paleta (`note_colors.dart`) são todas pasteis/claras de propósito, então
  // texto escuro fixo sempre contrasta bem, sem precisar calcular por nota.
  static const _ink = Color(0xDE000000); // black87
  static const _inkMuted = Color(0x8A000000); // black54

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = colorFromHex(note.color);
    final border = Color.lerp(background, Colors.black, 0.12)!;

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                  if (note.isPinned) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.push_pin, size: 16, color: _ink),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Renderiza o Markdown de verdade (não o texto cru com `#`/
              // `**` à mostra) - `IgnorePointer` porque o card inteiro já é
              // clicável (`onTap`), não queremos que um link dentro da
              // prévia capture o toque pra si. Sem `maxLines`/`ellipsis` de
              // propósito - o card cresce com o conteúdo, é o que faz o
              // `MasonryGridView` parecer um mural de verdade.
              IgnorePointer(
                child: MarkdownBody(
                  data: note.content,
                  styleSheet: MarkdownStyleSheet(
                    p: theme.textTheme.bodySmall?.copyWith(color: _inkMuted),
                    h1: theme.textTheme.titleMedium?.copyWith(color: _ink, fontWeight: FontWeight.bold),
                    h2: theme.textTheme.titleSmall?.copyWith(color: _ink, fontWeight: FontWeight.bold),
                    h3: theme.textTheme.bodyLarge?.copyWith(color: _ink, fontWeight: FontWeight.bold),
                    strong: const TextStyle(color: _ink, fontWeight: FontWeight.bold),
                    em: const TextStyle(color: _inkMuted, fontStyle: FontStyle.italic),
                    del: TextStyle(color: _inkMuted, decoration: TextDecoration.lineThrough),
                    listBullet: theme.textTheme.bodySmall?.copyWith(color: _inkMuted),
                    blockquote: theme.textTheme.bodySmall?.copyWith(color: _inkMuted, fontStyle: FontStyle.italic),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(left: BorderSide(color: _inkMuted)),
                    ),
                    code: theme.textTheme.bodySmall?.copyWith(
                      color: _ink,
                      backgroundColor: Colors.black.withValues(alpha: 0.08),
                      fontFamily: 'monospace',
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadii.sharp),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (projectName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.sharp),
                    ),
                    child: Text(
                      projectName!,
                      style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w500),
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
                            color: Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadii.sharp),
                          ),
                          child: Text(
                            tag,
                            style: theme.textTheme.labelSmall?.copyWith(color: _ink),
                          ),
                        ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Atualizado ${DateFormat('dd/MM/yyyy').format(note.updatedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: _inkMuted, fontSize: 11),
                      ),
                    ),
                    IconButton(
                      tooltip: note.isPinned ? 'Desafixar' : 'Fixar',
                      onPressed: onTogglePinned,
                      icon: Icon(
                        note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 16,
                        color: _ink,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
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
