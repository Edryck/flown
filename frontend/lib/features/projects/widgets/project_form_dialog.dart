import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/project.dart';
import '../../../core/models/project_type.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/form_section_card.dart';
import '../providers/project_list_controller.dart';
import '../providers/project_repository.dart';
import '../providers/project_type_repository.dart';

/// Abre o formulário de criação/edição de projeto como modal — mesmo
/// padrão de `showTaskFormDialog` (`task_form_dialog.dart`).
Future<void> showProjectFormDialog(BuildContext context, {Project? project}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ProjectFormDialog(initialProject: project),
  );
}

/// Cores fixas oferecidas no seletor — mesma paleta de 8 cores de
/// `ProjectForm.tsx` (`COLOR_OPTIONS`), mesmos hex e labels em português.
const _colorOptions = [
  (label: 'Azul', value: Color(0xFF4299E1)),
  (label: 'Verde', value: Color(0xFF48BB78)),
  (label: 'Âmbar', value: Color(0xFFED8936)),
  (label: 'Roxo', value: Color(0xFF9F7AEA)),
  (label: 'Teal', value: Color(0xFF68897F)),
  (label: 'Rosa', value: Color(0xFFED64A6)),
  (label: 'Vermelho', value: Color(0xFFF56565)),
  (label: 'Cinza', value: Color(0xFF718096)),
];

String _colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

/// Formulário de criação/edição de projeto — tradução de ProjectForm.tsx
/// (docs/prototype/screens/project-form.md), funcional de ponta a ponta
/// (o protótipo só simula sucesso com toast, não persiste nada) e como
/// modal, não tela cheia (mesma decisão do TaskForm). Diferenças
/// deliberadas do protótipo:
///   - cria E edita (protótipo só tinha `/projects/new`);
///   - sem os campos "Status"/"Prioridade"/"Data de Início"/"Prazo" do
///     card "Organização"/"Cronograma" — nenhum existe no `Project` real
///     (só no mock do protótipo, ver docs/prototype/screens/project-form.md);
///   - com um seletor de Tipo de Projeto (`ProjectType`, `typeId`) no lugar
///     deles — campo obrigatório no backend real que o protótipo nunca
///     modela (nem em `ProjectForm` nem em `TaskForm`);
///   - sem "Salvar rascunho" — mesma razão do TaskForm.
class _ProjectFormDialog extends ConsumerStatefulWidget {
  const _ProjectFormDialog({this.initialProject});

  final Project? initialProject;

  bool get isEdit => initialProject != null;

  @override
  ConsumerState<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<_ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _typeId;
  Color _color = _colorOptions.first.value;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final project = widget.initialProject;
    if (project != null) {
      _nameController.text = project.name;
      _descriptionController.text = project.description ?? '';
      _typeId = project.typeId;
      _color = Color(int.parse(project.color.replaceFirst('#', '0xFF')));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<ProjectType> types) async {
    if (!_formKey.currentState!.validate()) return;
    if (_typeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha um tipo de projeto')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final input = ProjectInput(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        color: _colorToHex(_color),
        typeId: _typeId,
      );

      final controller = ref.read(projectListControllerProvider.notifier);
      if (widget.isEdit) {
        await controller.updateProject(widget.initialProject!.id, input);
      } else {
        await controller.create(input);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.message : 'Erro inesperado ao salvar o projeto';
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
    final typesAsync = ref.watch(projectTypeListProvider);
    final types = typesAsync.valueOrNull ?? const <ProjectType>[];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 700, maxHeight: screenSize.height * 0.85),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEdit ? 'Editar Projeto' : 'Criar Novo Projeto',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          widget.isEdit
                              ? 'Atualize as informações do projeto'
                              : 'Preencha as informações para criar um novo projeto',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FormSectionCard(
                        title: 'Informações Básicas',
                        icon: Icons.info_outline,
                        description: 'Nome e do que se trata o projeto.',
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Nome do Projeto *'),
                            validator: (value) =>
                                (value == null || value.trim().length < 2) ? 'Nome muito curto' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(labelText: 'Descrição'),
                            maxLines: 4,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      FormSectionCard(
                        title: 'Organização',
                        icon: Icons.category_outlined,
                        description: 'Define quais status as tarefas desse projeto podem ter.',
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _typeId,
                            decoration: const InputDecoration(labelText: 'Tipo de Projeto *'),
                            items: [
                              for (final type in types) DropdownMenuItem(value: type.id, child: Text(type.name)),
                            ],
                            onChanged: (value) => setState(() => _typeId = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      FormSectionCard(
                        title: 'Cor do Projeto',
                        icon: Icons.palette_outlined,
                        description: 'Identificação visual nos cards e listas.',
                        children: [
                          Text(
                            'Escolha uma cor para identificar visualmente o projeto nos cards e listas.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final option in _colorOptions)
                                _ColorSwatch(
                                  color: option.value,
                                  label: option.label,
                                  selected: option.value.toARGB32() == _color.toARGB32(),
                                  onTap: () => setState(() => _color = option.value),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text.rich(
                            TextSpan(
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              children: [
                                const TextSpan(text: 'Cor selecionada: '),
                                TextSpan(
                                  text: _colorOptions.firstWhere((o) => o.value.toARGB32() == _color.toARGB32()).label,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : () => _submit(types),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.isEdit ? 'Salvar alterações' : 'Criar projeto'),
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

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.label, required this.selected, required this.onTap});

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
          width: 36,
          height: 36,
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

