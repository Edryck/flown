import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/note.dart';
import '../../../core/models/note_colors.dart';
import '../../../core/models/project.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/markdown_toolbar.dart';
import '../../projects/providers/project_list_controller.dart';
import '../providers/note_list_controller.dart';
import '../providers/note_repository.dart';

/// Abre o formulário de criação/edição de anotação como modal — mesmo
/// padrão de `showTaskFormDialog`/`showProjectFormDialog`. No protótipo
/// (`Notes.tsx`), "criar nota" já era sempre um modal sobre a lista, nunca
/// uma rota própria — aqui isso vale também pra edição.
Future<void> showNoteFormDialog(BuildContext context, {Note? note}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _NoteFormDialog(initialNote: note),
  );
}

/// Formulário de criação/edição de anotação — tradução de
/// `Notes.tsx` (docs/prototype/screens/notes.md), mas funcional de ponta a
/// ponta (`handleSaveNote` do protótipo só dava `console.log`, não
/// persistia nada) e também cobrindo edição (protótipo só tinha criação).
/// Diferenças deliberadas:
///   - Tags viram um chip-input (adicionar/remover) em vez do campo de
///     texto livre separado por vírgula do protótipo — mesmo padrão já
///     usado em `TaskFormDialog`, mais consistente entre as telas;
///   - "Projeto relacionado" casa por `projectId` (FK real), não pelo nome
///     do projeto como string (o protótipo usa `project.name` como valor);
///   - Adicionei um checkbox "Fixar esta anotação" — o protótipo nunca
///     mostra `pinned` como algo setável em lugar nenhum (só lê do mock),
///     mas o campo é real (`isPinned`) e precisa de alguma UI pra ser
///     definido.
class _NoteFormDialog extends ConsumerStatefulWidget {
  const _NoteFormDialog({this.initialNote});

  final Note? initialNote;

  bool get isEdit => initialNote != null;

  @override
  ConsumerState<_NoteFormDialog> createState() => _NoteFormDialogState();
}

class _NoteFormDialogState extends ConsumerState<_NoteFormDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();
  final _tagInputController = TextEditingController();

  final List<String> _tags = [];
  String? _projectId;
  bool _isPinned = false;
  bool _saving = false;
  Color _color = colorFromHex(defaultNoteColorHex);

  @override
  void initState() {
    super.initState();
    final note = widget.initialNote;
    if (note != null) {
      _titleController.text = note.title;
      _contentController.text = note.content;
      _tags.addAll(note.tags);
      _projectId = note.projectId;
      _isPinned = note.isPinned;
      _color = colorFromHex(note.color);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagInputController.text.trim();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag);
      _tagInputController.clear();
    });
  }

  void _removeTag(String tag) => setState(() => _tags.remove(tag));

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
      final input = NoteInput(
        title: title,
        content: _contentController.text.trim(),
        color: colorToHex(_color),
        tags: _tags,
        isPinned: _isPinned,
        projectId: _projectId,
      );

      final controller = ref.read(noteListControllerProvider.notifier);
      if (widget.isEdit) {
        await controller.updateNote(widget.initialNote!.id, input);
      } else {
        await controller.create(input);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.message : 'Erro inesperado ao salvar a anotação';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final projectsAsync = ref.watch(projectListControllerProvider);
    final projects = projectsAsync.valueOrNull ?? const <Project>[];
    final canSubmit = _titleController.text.trim().isNotEmpty;

    final metaFields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Título'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('Cor', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in noteColorOptions)
              _NoteColorSwatch(
                color: option.value,
                label: option.label,
                selected: option.value.toARGB32() == _color.toARGB32(),
                onTap: () => setState(() => _color = option.value),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Tags', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagInputController,
                decoration: const InputDecoration(hintText: 'Adicionar uma tag...'),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _addTag, child: const Icon(Icons.add, size: 18)),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _tags) Chip(label: Text(tag), onDeleted: () => _removeTag(tag)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: _projectId,
          decoration: const InputDecoration(labelText: 'Projeto relacionado (opcional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Nenhum')),
            for (final project in projects)
              DropdownMenuItem(value: project.id, child: Text(project.name)),
          ],
          onChanged: (value) => setState(() => _projectId = value),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _isPinned,
          onChanged: (value) => setState(() => _isPinned = value ?? false),
          title: const Text('Fixar esta anotação'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );

    final contentEditor = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Conteúdo', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Container(
          height: 360,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadii.sharp),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MarkdownToolbar(controller: _contentController, focusNode: _contentFocusNode),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    hintText: 'Escreva aqui... selecione um trecho e use a barra acima pra formatar.',
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900, maxHeight: screenSize.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEdit ? 'Editar Anotação' : 'Nova Anotação',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isEdit
                    ? 'Atualize os dados da anotação.'
                    : 'Crie uma nova anotação rapidamente. Preencha os campos abaixo.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Lado a lado só com espaço de sobra pra ambos - numa
                      // janela estreita empilha (meta em cima, conteúdo
                      // embaixo), mesmo padrão responsivo do resto do app.
                      if (constraints.maxWidth < 700) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            metaFields,
                            const SizedBox(height: 16),
                            contentEditor,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 280, child: metaFields),
                          const SizedBox(width: 24),
                          Expanded(child: contentEditor),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: (_saving || !canSubmit) ? null : _submit,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(widget.isEdit ? 'Salvar alterações' : 'Salvar anotação'),
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

class _NoteColorSwatch extends StatelessWidget {
  const _NoteColorSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sharp),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadii.sharp),
            border: selected
                ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
          ),
        ),
      ),
    );
  }
}
