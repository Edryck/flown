import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../notes/providers/note_list_controller.dart';
import '../../notes/providers/note_repository.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../projects/providers/project_repository.dart';
import '../../tasks/providers/task_list_controller.dart';
import '../../tasks/providers/task_repository.dart';
import 'archive_repository.dart';

part 'archive_list_controller.g.dart';

/// Conteúdo do arquivo + operação de desarquivar. Mesmo formato de
/// `TrashListController`, sem excluir/"esvaziar" (arquivo não é lixeira).
/// Depois de desarquivar um item, atualiza também a lista "ativa"
/// correspondente.
@riverpod
class ArchiveListController extends _$ArchiveListController {
  @override
  FutureOr<ArchiveContents> build() {
    return ref.watch(archiveRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(archiveRepositoryProvider).list());
  }

  ArchiveContents get _current =>
      state.valueOrNull ?? const ArchiveContents(projects: [], tasks: [], notes: []);

  Future<void> unarchiveProject(String id) async {
    await ref.read(projectRepositoryProvider).unarchive(id);
    state = AsyncData(
      ArchiveContents(
        projects: [for (final p in _current.projects) if (p.id != id) p],
        tasks: _current.tasks,
        notes: _current.notes,
      ),
    );
    await ref.read(projectListControllerProvider.notifier).refresh();
  }

  Future<void> unarchiveTask(String id) async {
    await ref.read(taskRepositoryProvider).unarchive(id);
    state = AsyncData(
      ArchiveContents(
        projects: _current.projects,
        tasks: [for (final t in _current.tasks) if (t.id != id) t],
        notes: _current.notes,
      ),
    );
    await ref.read(taskListControllerProvider.notifier).refresh();
  }

  Future<void> unarchiveNote(String id) async {
    await ref.read(noteRepositoryProvider).unarchive(id);
    state = AsyncData(
      ArchiveContents(
        projects: _current.projects,
        tasks: _current.tasks,
        notes: [for (final n in _current.notes) if (n.id != id) n],
      ),
    );
    await ref.read(noteListControllerProvider.notifier).refresh();
  }
}
