import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/note.dart';
import '../../../core/models/project.dart';
import '../../../core/widgets/screen_gradient_backdrop.dart';
import '../../projects/providers/project_list_controller.dart';
import '../providers/note_list_controller.dart';
import '../widgets/note_card.dart';
import '../widgets/note_form_dialog.dart';

enum _NoteFilter { all, pinned, withProject, withoutProject }

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
  _NoteFilter _filter = _NoteFilter.all;
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
    return switch (_filter) {
      _NoteFilter.all => result,
      _NoteFilter.pinned => result.where((n) => n.isPinned).toList(),
      _NoteFilter.withProject =>
        result.where((n) => n.projectId != null).toList(),
      _NoteFilter.withoutProject =>
        result.where((n) => n.projectId == null).toList(),
    };
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

  Future<void> _confirmDelete(Note note) async {
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
                        onEdit: (n) => showNoteFormDialog(context, note: n),
                        onDelete: _confirmDelete,
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
                      onEdit: (n) => showNoteFormDialog(context, note: n),
                      onDelete: _confirmDelete,
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
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePinned,
  });

  final List<Note> notes;
  final Map<String, String> projectNamesById;
  final ValueChanged<Note> onEdit;
  final ValueChanged<Note> onDelete;
  final ValueChanged<Note> onTogglePinned;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : (constraints.maxWidth >= 650 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: notes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 260,
          ),
          itemBuilder: (context, index) {
            final note = notes[index];
            return NoteCard(
              note: note,
              projectName: note.projectId == null
                  ? null
                  : projectNamesById[note.projectId],
              onEdit: () => onEdit(note),
              onDelete: () => onDelete(note),
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

/// Busca + filtro + ordenação — mesmo padrão visual de `_Toolbar` em
/// `ProjectsScreen` (busca e pílulas de filtro num `Wrap` à esquerda,
/// ordenação num `DropdownButton` fixo à direita), adaptado pros filtros
/// que fazem sentido pra uma anotação (sem status/prioridade como task).
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.onSearchChanged,
    required this.filter,
    required this.onFilterChanged,
    required this.sort,
    required this.onSortChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final _NoteFilter filter;
  final ValueChanged<_NoteFilter> onFilterChanged;
  final _NoteSort sort;
  final ValueChanged<_NoteSort> onSortChanged;

  static const _filterLabels = {
    _NoteFilter.all: 'Todas',
    _NoteFilter.pinned: 'Fixadas',
    _NoteFilter.withProject: 'Com Projeto',
    _NoteFilter.withoutProject: 'Sem Projeto',
  };

  static const _sortLabels = {
    _NoteSort.updatedAt: 'Mais Recentes',
    _NoteSort.title: 'Por Título',
    _NoteSort.createdAt: 'Por Data de Criação',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                for (final f in _NoteFilter.values)
                  filter == f
                      ? FilledButton(
                          onPressed: () => onFilterChanged(f),
                          child: Text(_filterLabels[f]!),
                        )
                      : OutlinedButton(
                          onPressed: () => onFilterChanged(f),
                          child: Text(_filterLabels[f]!),
                        ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<_NoteSort>(
            value: sort,
            underline: const SizedBox.shrink(),
            items: [
              for (final s in _NoteSort.values)
                DropdownMenuItem(value: s, child: Text(_sortLabels[s]!)),
            ],
            onChanged: (value) {
              if (value != null) onSortChanged(value);
            },
          ),
        ],
      ),
    );
  }
}
