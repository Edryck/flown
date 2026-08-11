import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/note.dart';
import 'note_repository.dart';

part 'note_list_controller.g.dart';

/// Lista de notas não deletadas do usuário + operações de mutação — mesmo
/// padrão de `TaskListController`/`ProjectListController`, `keepAlive: true`
/// incluso (mesmo motivo: evitar refetch/spinner ao voltar pra Notes depois
/// de passar por uma tela que não observa esse provider).
@Riverpod(keepAlive: true)
class NoteListController extends _$NoteListController {
  @override
  FutureOr<List<Note>> build() {
    return ref.watch(noteRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(noteRepositoryProvider).list());
  }

  Future<Note> create(NoteInput input) async {
    final note = await ref.read(noteRepositoryProvider).create(input);
    state = AsyncData([...?state.valueOrNull, note]);
    return note;
  }

  /// Nome `updateNote` (não `update`) de propósito — `AsyncNotifier` já tem
  /// um método `update` embutido com assinatura incompatível.
  Future<Note> updateNote(String id, NoteInput input) async {
    final note = await ref.read(noteRepositoryProvider).update(id, input);
    state = AsyncData([for (final n in state.valueOrNull ?? const <Note>[]) if (n.id == id) note else n]);
    return note;
  }

  Future<void> togglePinned(Note note) {
    return updateNote(note.id, NoteInput(isPinned: !note.isPinned));
  }

  Future<void> delete(String id) async {
    await ref.read(noteRepositoryProvider).softDelete(id);
    state = AsyncData([for (final n in state.valueOrNull ?? const <Note>[]) if (n.id != id) n]);
  }
}
