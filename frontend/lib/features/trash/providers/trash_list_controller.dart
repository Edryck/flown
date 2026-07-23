import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../notes/providers/note_list_controller.dart';
import '../../notes/providers/note_repository.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../projects/providers/project_repository.dart';
import '../../tasks/providers/task_list_controller.dart';
import '../../tasks/providers/task_repository.dart';
import 'trash_repository.dart';

part 'trash_list_controller.g.dart';

/// Conteúdo da lixeira + operações de restaurar/excluir definitivamente.
/// Depois de restaurar um item, atualiza também a lista "ativa"
/// correspondente (`ProjectListController`/`TaskListController`/
/// `NoteListController`) — sem isso, o item restaurado só reapareceria nas
/// telas normais depois de um reload manual.
@riverpod
class TrashListController extends _$TrashListController {
  @override
  FutureOr<TrashContents> build() {
    return ref.watch(trashRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(trashRepositoryProvider).list());
  }

  TrashContents get _current =>
      state.valueOrNull ?? const TrashContents(projects: [], tasks: [], notes: []);

  Future<void> restoreProject(String id) async {
    await ref.read(projectRepositoryProvider).restore(id);
    state = AsyncData(
      TrashContents(
        projects: [for (final p in _current.projects) if (p.id != id) p],
        tasks: _current.tasks,
        notes: _current.notes,
      ),
    );
    await ref.read(projectListControllerProvider.notifier).refresh();
  }

  Future<void> restoreTask(String id) async {
    await ref.read(taskRepositoryProvider).restore(id);
    state = AsyncData(
      TrashContents(
        projects: _current.projects,
        tasks: [for (final t in _current.tasks) if (t.id != id) t],
        notes: _current.notes,
      ),
    );
    await ref.read(taskListControllerProvider.notifier).refresh();
  }

  Future<void> restoreNote(String id) async {
    await ref.read(noteRepositoryProvider).restore(id);
    state = AsyncData(
      TrashContents(
        projects: _current.projects,
        tasks: _current.tasks,
        notes: [for (final n in _current.notes) if (n.id != id) n],
      ),
    );
    await ref.read(noteListControllerProvider.notifier).refresh();
  }

  Future<void> permanentDeleteProject(String id) async {
    await ref.read(projectRepositoryProvider).permanentDelete(id);
    state = AsyncData(
      TrashContents(
        projects: [for (final p in _current.projects) if (p.id != id) p],
        tasks: _current.tasks,
        notes: _current.notes,
      ),
    );
  }

  Future<void> permanentDeleteTask(String id) async {
    await ref.read(taskRepositoryProvider).permanentDelete(id);
    state = AsyncData(
      TrashContents(
        projects: _current.projects,
        tasks: [for (final t in _current.tasks) if (t.id != id) t],
        notes: _current.notes,
      ),
    );
  }

  Future<void> permanentDeleteNote(String id) async {
    await ref.read(noteRepositoryProvider).permanentDelete(id);
    state = AsyncData(
      TrashContents(
        projects: _current.projects,
        tasks: _current.tasks,
        notes: [for (final n in _current.notes) if (n.id != id) n],
      ),
    );
  }

  Future<void> emptyTrash() async {
    await ref.read(trashRepositoryProvider).emptyTrash();
    state = const AsyncData(TrashContents(projects: [], tasks: [], notes: []));
  }
}
