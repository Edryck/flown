import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/models/note.dart';
import '../../../core/models/project.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/screen_gradient_backdrop.dart';
import '../../projects/providers/project_list_controller.dart';
import '../providers/note_list_controller.dart';
import '../widgets/note_card.dart';
import '../widgets/note_form_dialog.dart';
import '../widgets/note_view_dialog.dart';

/// Seleção atual de filtros da tela de Notes — mesmo padrão de
/// `TaskFilterSelection` (`task_filter_dialog.dart`): conjunto vazio em
/// `projectIds` significa "sem filtro de projeto". `null` dentro do set
/// representa o bucket "Sem Projeto" (nota sem `projectId`), ao lado dos ids
/// reais de projetos específicos.
class _NoteFilterSelection {
  const _NoteFilterSelection({
    this.pinnedOnly = false,
    this.projectIds = const {},
  });

  final bool pinnedOnly;
  final Set<String?> projectIds;

  int get activeCount =>
      (pinnedOnly ? 1 : 0) + (projectIds.isNotEmpty ? 1 : 0);
}

enum _NoteSort { updatedAt, title, createdAt }

/// Tela de anotações — tradução fiel de Notes.tsx
/// (docs/prototype/screens/notes.md): busca, seção "Fixadas" (só aparece
/// se houver notas fixadas) + "Todas as Anotações", grade de 3 colunas,
/// estado vazio. Dados reais (`NoteListController`). Filtrar/Ordenar
/// funcionais (mesmo padrão visual de `_Toolbar` em `ProjectsScreen` —
/// eram decorativos, sem `onClick`, tanto no protótipo quanto na primeira
/// tradução). Criar/editar é sempre modal, nunca rota própria — igual ao
/// protótipo já fazia pra criação (`/notes/new` cai no mesmo componente
/// `Notes` com um dialog), estendido aqui pra edição também.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _NoteFilterSelection _filter = const _NoteFilterSelection();
  _NoteSort _sort = _NoteSort.updatedAt;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Note> _applyFilters(List<Note> notes) {
    var result = notes;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((note) {
        return note.title.toLowerCase().contains(query) ||
            note.content.toLowerCase().contains(query) ||
            note.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }
    if (_filter.pinnedOnly) {
      result = result.where((n) => n.isPinned).toList();
    }
    if (_filter.projectIds.isNotEmpty) {
      result = result
          .where((n) => _filter.projectIds.contains(n.projectId))
          .toList();
    }
    return result;
  }

  List<Note> _applySort(List<Note> notes) {
    final sorted = [...notes];
    switch (_sort) {
      case _NoteSort.updatedAt:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case _NoteSort.title:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case _NoteSort.createdAt:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notesAsync = ref.watch(noteListControllerProvider);
    final projectsAsync = ref.watch(projectListControllerProvider);
    final projectNamesById = <String, String>{
      for (final p in projectsAsync.valueOrNull ?? const <Project>[])
        p.id: p.name,
    };

    return ScreenGradientBackdrop(
      child: SingleChildScrollView(
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
                    Text(
                      'Anotações',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Capture seus pensamentos e ideias',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () => showNoteFormDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nova Anotação'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _Toolbar(
              searchController: _searchController,
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              filter: _filter,
              onFilterChanged: (f) => setState(() => _filter = f),
              projects: projectsAsync.valueOrNull ?? const [],
              sort: _sort,
              onSortChanged: (s) => setState(() => _sort = s),
            ),
            const SizedBox(height: 24),
            notesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text('Erro ao carregar anotações: $error'),
                ),
              ),
              data: (notes) {
                final filtered = _applySort(_applyFilters(notes));
                final pinned = filtered.where((n) => n.isPinned).toList();
                final unpinned = filtered.where((n) => !n.isPinned).toList();

                if (filtered.isEmpty) {
                  return _EmptyState(theme: theme);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pinned.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.push_pin_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Fixadas',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _NotesGrid(
                        notes: pinned,
                        projectNamesById: projectNamesById,
                        onTap: (n) => showNoteViewDialog(context, note: n),
                        onTogglePinned: (n) => ref
                            .read(noteListControllerProvider.notifier)
                            .togglePinned(n),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (pinned.isNotEmpty) ...[
                      Text(
                        'Todas as Anotações',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _NotesGrid(
                      notes: unpinned,
                      projectNamesById: projectNamesById,
                      onTap: (n) => showNoteViewDialog(context, note: n),
                      onTogglePinned: (n) => ref
                          .read(noteListControllerProvider.notifier)
                          .togglePinned(n),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({
    required this.notes,
    required this.projectNamesById,
    required this.onTap,
    required this.onTogglePinned,
  });

  final List<Note> notes;
  final Map<String, String> projectNamesById;
  final ValueChanged<Note> onTap;
  final ValueChanged<Note> onTogglePinned;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : (constraints.maxWidth >= 650 ? 2 : 1);
        // Masonry (não `GridView` com `mainAxisExtent` fixo) de propósito -
        // cada card agora tem cor/altura próprias (nota com mais tags/chip
        // de projeto fica mais alta), um grid de linhas uniformes escondia
        // essa variação forçando tudo na mesma altura. Lembra mais um mural
        // de recados assim.
        return MasonryGridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return NoteCard(
              note: note,
              projectName: note.projectId == null
                  ? null
                  : projectNamesById[note.projectId],
              onTap: () => onTap(note),
              onTogglePinned: () => onTogglePinned(note),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // `width: double.infinity` de propósito — sem isso, o Column encolhe
    // pro tamanho do próprio conteúdo e fica grudado à esquerda (o Column
    // pai, em NotesScreen, usa crossAxisAlignment.start).
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search,
                size: 28,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma anotação encontrada',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Busca + Filtrar (diálogo) + Ordenar (menu) — mesmo padrão da tela de
/// Tasks e agora de Projects (ver `_Toolbar`/`_ProjectFilterDialog` em
/// `projects_screen.dart`): filtro escondido atrás de um botão em vez de
/// pílulas sempre visíveis.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.onSearchChanged,
    required this.filter,
    required this.onFilterChanged,
    required this.projects,
    required this.sort,
    required this.onSortChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final _NoteFilterSelection filter;
  final ValueChanged<_NoteFilterSelection> onFilterChanged;
  final List<Project> projects;
  final _NoteSort sort;
  final ValueChanged<_NoteSort> onSortChanged;

  static const _sortLabels = {
    _NoteSort.updatedAt: 'Mais Recentes',
    _NoteSort.title: 'Por Título',
    _NoteSort.createdAt: 'Por Data de Criação',
  };

  Future<void> _openFilterDialog(BuildContext context) async {
    final selected = await showDialog<_NoteFilterSelection>(
      context: context,
      builder: (context) =>
          _NoteFilterDialog(initial: filter, projects: projects),
    );
    if (selected != null) onFilterChanged(selected);
  }

  Future<void> _openSortMenu(BuildContext buttonContext) async {
    final button = buttonContext.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<_NoteSort>(
      context: buttonContext,
      position: position,
      items: [
        for (final s in _NoteSort.values)
          PopupMenuItem(value: s, child: Text(_sortLabels[s]!)),
      ],
    );
    if (selected != null) onSortChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            height: 36,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: 'Pesquisar anotações...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sharp),
                ),
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => _openFilterDialog(context),
            icon: Icon(
              Icons.filter_list,
              size: 16,
              color: filter.activeCount > 0 ? theme.colorScheme.primary : null,
            ),
            label: Text(
              filter.activeCount > 0
                  ? 'Filtrar (${filter.activeCount})'
                  : 'Filtrar',
            ),
          ),
          const SizedBox(width: 8),
          Builder(
            builder: (buttonContext) => OutlinedButton.icon(
              onPressed: () => _openSortMenu(buttonContext),
              icon: const Icon(Icons.sort, size: 16),
              label: Text('Ordenar: ${_sortLabels[sort]}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteFilterDialog extends StatefulWidget {
  const _NoteFilterDialog({required this.initial, required this.projects});

  final _NoteFilterSelection initial;
  final List<Project> projects;

  @override
  State<_NoteFilterDialog> createState() => _NoteFilterDialogState();
}

class _NoteFilterDialogState extends State<_NoteFilterDialog> {
  late bool _pinnedOnly = widget.initial.pinnedOnly;
  late Set<String?> _projectIds = {...widget.initial.projectIds};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Filtrar anotações'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Projeto', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Sem Projeto'),
                    selected: _projectIds.contains(null),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _projectIds.add(null);
                      } else {
                        _projectIds.remove(null);
                      }
                    }),
                  ),
                  for (final project in widget.projects)
                    FilterChip(
                      label: Text(project.name),
                      selected: _projectIds.contains(project.id),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _projectIds.add(project.id);
                        } else {
                          _projectIds.remove(project.id);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _pinnedOnly,
                onChanged: (value) =>
                    setState(() => _pinnedOnly = value ?? false),
                title: const Text('Somente fixadas'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _pinnedOnly = false;
            _projectIds = {};
          }),
          child: const Text('Limpar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _NoteFilterSelection(
              pinnedOnly: _pinnedOnly,
              projectIds: _projectIds,
            ),
          ),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
