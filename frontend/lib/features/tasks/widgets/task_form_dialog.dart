import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/checklist_item.dart';
import '../../../core/models/project.dart';
import '../../../core/models/project_type.dart';
import '../../../core/models/task.dart';
import '../../../core/models/task_priority.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../projects/providers/project_type_repository.dart';
import '../../settings/providers/settings_preferences.dart';
import '../providers/task_list_controller.dart';
import '../providers/task_repository.dart';
import '../utils/task_status_colors.dart';

/// Abre o formulário de criação/edição de tarefa como modal, por cima da
/// tela atual (Kanban/Tabela/Calendário/etc.) — ao contrário de uma rota
/// própria, não perde a view/scroll de onde foi chamado, e fecha sozinho
/// (`Navigator.pop`) ao salvar ou cancelar.
///
/// `initialParentTaskId`/`initialProjectId` só valem em modo criação (com
/// `task == null`) — usados pelo `SubtasksGraphDialog` ao abrir "Adicionar
/// subtarefa": pré-popula o projeto do pai (pra já vir com status válidos
/// disponíveis) e amarra a nova task como subtarefa dele.
Future<void> showTaskFormDialog(
  BuildContext context, {
  Task? task,
  String? initialParentTaskId,
  String? initialProjectId,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _TaskFormDialog(
      initialTask: task,
      initialParentTaskId: initialParentTaskId,
      initialProjectId: initialProjectId,
    ),
  );
}

/// Conteúdo do formulário — tradução de TaskForm.tsx
/// (docs/prototype/screens/task-form.md), mas funcional de ponta a ponta
/// (o protótipo era majoritariamente decorativo: campos não controlados,
/// submit não persistia nada) e como modal, não tela cheia (decisão
/// posterior à tradução — o protótipo abre TaskForm como rota própria,
/// `/tasks/new`). Diferenças deliberadas, decididas antes de traduzir esta
/// tela:
///   - cria E edita (o protótipo só tinha `/tasks/new`) — reaproveita o
///     mesmo layout pros dois modos, já que não há referência visual de
///     edição no protótipo;
///   - Status não é mais uma lista fixa de 5 valores — vem de
///     `ProjectType.availableStatus` do projeto selecionado (vazio/oculto
///     sem projeto, já que o backend não valida status sem projeto);
///   - Checklist tem checkbox de verdade (`done`), e marcar item altera o
///     `progress` da task automaticamente (% de itens concluídos) — sem
///     isso, o checklist ficava desconectado da barra de progresso mostrada
///     em `TasksTableView`;
///   - Sem "Salvar rascunho" — não existe conceito de rascunho no backend,
///     manter o botão decorativo contradiria o resto da tela ser funcional.
class _TaskFormDialog extends ConsumerStatefulWidget {
  const _TaskFormDialog({
    this.initialTask,
    this.initialParentTaskId,
    this.initialProjectId,
  });

  /// `null` = modo criação. Presente = modo edição, pré-popula o form.
  final Task? initialTask;
  final String? initialParentTaskId;
  final String? initialProjectId;

  bool get isEdit => initialTask != null;

  @override
  ConsumerState<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<_TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _estimatedTimeController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _checklistInputController = TextEditingController();

  final List<String> _tags = [];
  final List<ChecklistItem> _checklist = [];

  String? _projectId;
  String? _status;
  String? _parentTaskId;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    if (task != null) {
      _titleController.text = task.title;
      _descriptionController.text = task.description ?? '';
      _estimatedTimeController.text = task.estimatedTime ?? '';
      _tags.addAll(task.tags);
      _checklist.addAll(task.checklist);
      _projectId = task.projectId;
      _status = task.status;
      _parentTaskId = task.parentTaskId;
      _priority = task.priority;
      if (task.dueDate != null) {
        final due = task.dueDate!;
        _dueDate = DateTime(due.year, due.month, due.day);
        if (due.hour != 0 || due.minute != 0) {
          _dueTime = TimeOfDay(hour: due.hour, minute: due.minute);
        }
      }
    } else {
      // Prioridade padrão configurada em Settings (`settings_preferences.dart`)
      // — só se aplica na criação, edição sempre parte da prioridade real da task.
      _priority =
          ref
              .read(settingsPreferencesControllerProvider)
              .valueOrNull
              ?.defaultPriority ??
          TaskPriority.medium;
      _projectId = widget.initialProjectId;
      _parentTaskId = widget.initialParentTaskId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedTimeController.dispose();
    _tagInputController.dispose();
    _checklistInputController.dispose();
    super.dispose();
  }

  List<String> _availableStatusFor(
    List<Project> projects,
    List<ProjectType> types,
  ) {
    if (_projectId == null) return const [];
    final project = projects.where((p) => p.id == _projectId).firstOrNull;
    if (project == null) return const [];
    final type = types.where((t) => t.id == project.typeId).firstOrNull;
    return type?.availableStatus ?? const [];
  }

  void _onProjectChanged(
    String? projectId,
    List<Project> projects,
    List<ProjectType> types,
  ) {
    setState(() {
      _projectId = projectId;
      final available = _availableStatusFor(projects, types);
      _status = available.contains(_status)
          ? _status
          : (available.isEmpty ? null : available.first);
    });
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

  void _addChecklistItem() {
    final text = _checklistInputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checklist.add(ChecklistItem(text: text, done: false));
      _checklistInputController.clear();
    });
  }

  void _removeChecklistItem(int index) =>
      setState(() => _checklist.removeAt(index));

  void _toggleChecklistItem(int index, bool done) {
    setState(
      () => _checklist[index] = ChecklistItem(
        text: _checklist[index].text,
        done: done,
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  /// % de itens concluídos do checklist (mesmo cálculo do
  /// `calculateChecklistProgress` do protótipo, `utils/helpers.ts`) — vira
  /// o `progress` da task, que é o que `TasksTableView` mostra na barra.
  /// Sem checklist, não mexe no `progress` existente (`unset`).
  Object? _resolveProgress() {
    if (_checklist.isEmpty) return unset;
    final done = _checklist.where((c) => c.done).length;
    return ((done / _checklist.length) * 100).round();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      DateTime? dueDate;
      if (_dueDate != null) {
        dueDate = _dueTime == null
            ? _dueDate
            : DateTime(
                _dueDate!.year,
                _dueDate!.month,
                _dueDate!.day,
                _dueTime!.hour,
                _dueTime!.minute,
              );
      }

      final input = TaskInput(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        status: _projectId == null ? unset : _status,
        priority: _priority,
        dueDate: dueDate,
        progress: _resolveProgress(),
        estimatedTime: _estimatedTimeController.text.trim().isEmpty
            ? null
            : _estimatedTimeController.text.trim(),
        tags: _tags,
        checklist: _checklist,
        projectId: _projectId,
        parentTaskId: _parentTaskId,
      );

      final controller = ref.read(taskListControllerProvider.notifier);
      if (widget.isEdit) {
        await controller.updateTask(widget.initialTask!.id, input);
      } else {
        await controller.create(input);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        final message = e is ApiException
            ? e.message
            : 'Erro inesperado ao salvar a tarefa';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
    final typesAsync = ref.watch(projectTypeListProvider);
    final projects = projectsAsync.valueOrNull ?? const <Project>[];
    final types = typesAsync.valueOrNull ?? const <ProjectType>[];
    final availableStatus = _availableStatusFor(projects, types);
    // Subtarefa não tem vencimento próprio (herda o da tarefa-mãe, imposto
    // pelo backend em `task.service.ts`) — resolve o valor herdado só pra
    // exibir, já que o campo de data fica escondido nesse caso.
    final parentDueDate = _parentTaskId == null
        ? null
        : ref
              .watch(taskListControllerProvider)
              .valueOrNull
              ?.where((t) => t.id == _parentTaskId)
              .firstOrNull
              ?.dueDate;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: screenSize.height * 0.85,
        ),
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
                          widget.isEdit
                              ? 'Editar Tarefa'
                              : (_parentTaskId != null
                                    ? 'Nova Subtarefa'
                                    : 'Criar Nova Tarefa'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.isEdit
                              ? 'Atualize os dados da tarefa'
                              : (_parentTaskId != null
                                    ? 'Adicione uma subtarefa'
                                    : 'Adicione uma nova tarefa ao seu fluxo de trabalho'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
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
                      _FormCard(
                        title: 'Informações Básicas',
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Título da Tarefa *',
                            ),
                            validator: (value) =>
                                (value == null || value.trim().length < 2)
                                ? 'Título muito curto'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Descrição',
                            ),
                            maxLines: 4,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _FormCard(
                        title: 'Organização',
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _projectId,
                                  decoration: const InputDecoration(
                                    labelText: 'Projeto',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('Nenhum projeto'),
                                    ),
                                    for (final project in projects)
                                      DropdownMenuItem(
                                        value: project.id,
                                        child: Text(project.name),
                                      ),
                                  ],
                                  onChanged: (value) =>
                                      _onProjectChanged(value, projects, types),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: availableStatus.isEmpty
                                    ? InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Status',
                                        ),
                                        child: Text(
                                          'Selecione um projeto',
                                          style: TextStyle(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    : DropdownButtonFormField<String>(
                                        // `initialValue` só é lido no primeiro build do FormField —
                                        // sem essa `key`, quando `_status` é resetado
                                        // programaticamente (troca de projeto em
                                        // `_onProjectChanged`), o dropdown continua mostrando o
                                        // valor antigo mesmo com `_status` já atualizado.
                                        key: ValueKey(_status),
                                        initialValue: _status,
                                        decoration: const InputDecoration(
                                          labelText: 'Status',
                                        ),
                                        items: [
                                          for (final status in availableStatus)
                                            DropdownMenuItem(
                                              value: status,
                                              child: Text(
                                                statusLabelPtBr(status),
                                              ),
                                            ),
                                        ],
                                        onChanged: (value) =>
                                            setState(() => _status = value),
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<TaskPriority>(
                                  initialValue: _priority,
                                  decoration: const InputDecoration(
                                    labelText: 'Prioridade',
                                  ),
                                  items: [
                                    for (final priority in TaskPriority.values)
                                      DropdownMenuItem(
                                        value: priority,
                                        child: Text(
                                          PriorityBadge.labels[priority]!,
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _priority =
                                        value ?? TaskPriority.medium,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _estimatedTimeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Tempo Estimado',
                                    hintText: 'ex: 4 horas',
                                  ),
                                ),
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
                                  decoration: const InputDecoration(
                                    hintText: 'Adicionar uma tag...',
                                  ),
                                  onSubmitted: (_) => _addTag(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _addTag,
                                child: const Icon(Icons.add, size: 18),
                              ),
                            ],
                          ),
                          if (_tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final tag in _tags)
                                  Chip(
                                    label: Text(tag),
                                    onDeleted: () => _removeTag(tag),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),

                      _FormCard(
                        title: 'Cronograma',
                        children: [
                          if (_parentTaskId != null)
                            // Subtarefa não define vencimento próprio — só
                            // mostra o herdado da tarefa-mãe, sem seletor.
                            Text(
                              parentDueDate == null
                                  ? 'Sem vencimento (herdado da tarefa-mãe)'
                                  : 'Vence em ${DateFormat('dd/MM/yyyy').format(parentDueDate)} (herdado da tarefa-mãe)',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _pickDueDate,
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Prazo',
                                      ),
                                      child: Text(
                                        _dueDate == null
                                            ? 'Selecionar data'
                                            : DateFormat(
                                                'dd/MM/yyyy',
                                              ).format(_dueDate!),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: InkWell(
                                    onTap: _pickDueTime,
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Horário do prazo (opcional)',
                                      ),
                                      child: Text(
                                        _dueTime == null
                                            ? 'Selecionar horário'
                                            : _dueTime!.format(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _FormCard(
                        title: 'Lista de Verificação',
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _checklistInputController,
                                  decoration: const InputDecoration(
                                    hintText: 'Adicionar item à lista...',
                                  ),
                                  onSubmitted: (_) => _addChecklistItem(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _addChecklistItem,
                                child: const Icon(Icons.add, size: 18),
                              ),
                            ],
                          ),
                          if (_checklist.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            for (var i = 0; i < _checklist.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: _checklist[i].done,
                                        onChanged: (v) =>
                                            _toggleChecklistItem(i, v ?? false),
                                      ),
                                      Expanded(child: Text(_checklist[i].text)),
                                      IconButton(
                                        onPressed: () =>
                                            _removeChecklistItem(i),
                                        icon: const Icon(Icons.close, size: 18),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
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
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.isEdit
                                  ? 'Salvar alterações'
                                  : 'Criar tarefa',
                            ),
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

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
