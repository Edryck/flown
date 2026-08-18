import 'package:flutter/material.dart';

/// Barra de formatação pra um campo de texto que grava Markdown - o usuário
/// nunca precisa saber a sintaxe (`**negrito**`, `# título`...), só
/// selecionar texto e clicar no botão; quem escreve o Markdown de verdade é
/// o helper aqui, o campo continua sendo um `TextField` normal por baixo.
/// Não inclui as ações de IA (traduzir/reescrever) que a referência do
/// pedido tinha - isso exigiria uma API de LLM externa, fora do escopo
/// deste editor.
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({super.key, required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Envolve a seleção atual com [prefix]/[suffix] (`**txto**`, `*txto*`,
  /// `~~txto~~`) - sem seleção, insere o par vazio com o cursor no meio, pra
  /// já poder digitar.
  void _wrapSelection(String prefix, String suffix) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final selected = text.substring(start, end);

    final newText = text.replaceRange(start, end, '$prefix$selected$suffix');
    controller.value = TextEditingValue(
      text: newText,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: start + prefix.length)
          : TextSelection(
              baseOffset: start + prefix.length,
              extentOffset: start + prefix.length + selected.length,
            ),
    );
    focusNode.requestFocus();
  }

  /// Prefixa cada linha do bloco selecionado com [prefix] (`# `, `- `) - só
  /// a linha do cursor, se não houver seleção espalhada por várias linhas.
  void _prefixLines(String prefix) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start < 0 ? 0 : selection.start;
    final end = selection.end < 0 ? 0 : selection.end;

    final lineStart = text.lastIndexOf('\n', (start - 1).clamp(0, text.length)) + 1;
    final nextBreak = text.indexOf('\n', end);
    final lineEnd = nextBreak == -1 ? text.length : nextBreak;

    final block = text.substring(lineStart, lineEnd);
    final newBlock = block.isEmpty
        ? prefix
        : block.split('\n').map((line) => '$prefix$line').join('\n');
    final newText = text.replaceRange(lineStart, lineEnd, newBlock);
    final delta = newBlock.length - block.length;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: (start + prefix.length).clamp(0, newText.length),
        extentOffset: (end + delta).clamp(0, newText.length),
      ),
    );
    focusNode.requestFocus();
  }

  void _insertLink() {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final label = text.substring(start, end);
    final displayLabel = label.isEmpty ? 'link' : label;
    const placeholderUrl = 'https://';
    final insertion = '[$displayLabel]($placeholderUrl)';

    final newText = text.replaceRange(start, end, insertion);
    final urlStart = start + 1 + displayLabel.length + 2; // depois de "[label]("
    controller.value = TextEditingValue(
      text: newText,
      // Seleciona o placeholder da URL, não o texto do link - próximo passo
      // óbvio do usuário é digitar o endereço de verdade por cima.
      selection: TextSelection(
        baseOffset: urlStart,
        extentOffset: urlStart + placeholderUrl.length,
      ),
    );
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Wrap(
        children: [
          _ToolbarButton(
            icon: Icons.format_bold,
            tooltip: 'Negrito',
            onTap: () => _wrapSelection('**', '**'),
          ),
          _ToolbarButton(
            icon: Icons.format_italic,
            tooltip: 'Itálico',
            onTap: () => _wrapSelection('*', '*'),
          ),
          _ToolbarButton(
            icon: Icons.strikethrough_s,
            tooltip: 'Riscado',
            onTap: () => _wrapSelection('~~', '~~'),
          ),
          const _ToolbarDivider(),
          _ToolbarButton(
            icon: Icons.title,
            tooltip: 'Título',
            onTap: () => _prefixLines('## '),
          ),
          _ToolbarButton(
            icon: Icons.format_list_bulleted,
            tooltip: 'Lista',
            onTap: () => _prefixLines('- '),
          ),
          _ToolbarButton(
            icon: Icons.format_quote,
            tooltip: 'Citação',
            onTap: () => _prefixLines('> '),
          ),
          const _ToolbarDivider(),
          _ToolbarButton(icon: Icons.link, tooltip: 'Link', onTap: _insertLink),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        splashRadius: 18,
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}
