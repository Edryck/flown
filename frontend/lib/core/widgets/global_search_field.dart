import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notes/widgets/note_form_dialog.dart';
import '../../features/projects/widgets/project_view_dialog.dart';
import '../../features/search/providers/search_repository.dart';
import '../../features/tasks/widgets/task_view_dialog.dart';
import '../models/note.dart';
import '../models/project.dart';
import '../models/task.dart';
import 'search_results_panel.dart';

/// Busca global (cross-entidade: tasks+projects+notes) - mora no Dashboard,
/// não na navegação (`AppSidebar`/`TopNavBar`), porque cada tela de lista
/// (Tasks/Projects/Notes) já tem seu próprio campo de busca local/filtrado
/// (`tasks_screen.dart` etc.) - duplicar a busca global na navegação não
/// tinha propósito. Mesma mecânica de dropdown ancorado que o `TopNavBar`
/// usava antes de a navegação virar sidebar.
class GlobalSearchField extends ConsumerStatefulWidget {
  const GlobalSearchField({super.key, this.width = 320});

  final double width;

  @override
  ConsumerState<GlobalSearchField> createState() => _GlobalSearchFieldState();
}

class _GlobalSearchFieldState extends ConsumerState<GlobalSearchField> {
  static const _groupId = 'dashboard-global-search';

  final _controller = TextEditingController();
  final _layerLink = LayerLink();
  final _overlayController = OverlayPortalController();
  Timer? _debounce;
  Future<SearchResults>? _future;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _future = null);
      _overlayController.hide();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      // Bloco (não `=>`) de propósito - ver a mesma nota em `top_nav_bar.dart`.
      setState(() {
        _future = ref.read(searchRepositoryProvider).search(query);
      });
      _overlayController.show();
    });
  }

  void _close() {
    _debounce?.cancel();
    _overlayController.hide();
    _controller.clear();
    setState(() => _future = null);
  }

  void _openTask(Task task) {
    _close();
    context.go('/tasks');
    showTaskViewDialog(context, task: task);
  }

  void _openProject(Project project) {
    _close();
    context.go('/projects');
    showProjectViewDialog(context, project: project);
  }

  void _openNote(Note note) {
    _close();
    context.go('/notes');
    showNoteFormDialog(context, note: note);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TapRegion(
        groupId: _groupId,
        onTapOutside: (_) {
          if (_future != null) _close();
        },
        child: OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: (context) => CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            offset: const Offset(0, 8),
            child: TapRegion(
              groupId: _groupId,
              child: Align(
                alignment: Alignment.topLeft,
                child: SearchResultsPanel(
                  width: widget.width,
                  future: _future,
                  onTapTask: _openTask,
                  onTapProject: _openProject,
                  onTapNote: _openNote,
                ),
              ),
            ),
          ),
          child: SizedBox(
            width: widget.width,
            height: 40,
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: _close,
                      ),
                hintText: 'Buscar tarefas, projetos, anotações...',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
