import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/note.dart';

part 'note_repository.g.dart';

/// Sentinela pra distinguir "campo não enviado no PATCH" de "campo enviado
/// como null" — mesma ideia de `Unset`/`unset` em `task_repository.dart`.
class NoteFieldUnset {
  const NoteFieldUnset._();
}

const noteFieldUnset = NoteFieldUnset._();

/// Corpo de `POST`/`PATCH /notes` (espelha `createNoteSchema`/
/// `updateNoteSchema`, `backend/src/schemas/note.schema.ts`).
class NoteInput {
  const NoteInput({
    this.title = noteFieldUnset,
    this.content = noteFieldUnset,
    this.color = noteFieldUnset,
    this.tags = noteFieldUnset,
    this.isPinned = noteFieldUnset,
    this.projectId = noteFieldUnset,
  });

  final Object? title;
  final Object? content;
  final Object? color;
  final Object? tags;
  final Object? isPinned;
  final Object? projectId;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value is NoteFieldUnset) return;
      json[key] = value;
    }

    put('title', title);
    put('content', content);
    put('color', color);
    put('tags', tags);
    put('isPinned', isPinned);
    put('projectId', projectId);
    return json;
  }
}

/// Fala com `/notes/*`. Nunca chamado direto pelas telas — sempre por trás
/// de `NoteListController`, que mantém a lista em memória sincronizada.
class NoteRepository {
  NoteRepository(this._dio);

  final Dio _dio;

  Future<List<Note>> list() {
    return guardApiCall(() async {
      final response = await _dio.get<List<dynamic>>('/notes', queryParameters: {'isDeleted': 'false'});
      return response.data!.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  Future<Note> create(NoteInput input) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>('/notes', data: input.toJson());
      return Note.fromJson(response.data!);
    });
  }

  Future<Note> update(String id, NoteInput input) {
    return guardApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>('/notes/$id', data: input.toJson());
      return Note.fromJson(response.data!);
    });
  }

  Future<Note> softDelete(String id) {
    return guardApiCall(() async {
      final response = await _dio.delete<Map<String, dynamic>>('/notes/$id');
      return Note.fromJson(response.data!);
    });
  }

  Future<Note> restore(String id) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>('/notes/$id/restore');
      return Note.fromJson(response.data!);
    });
  }

  Future<void> permanentDelete(String id) {
    return guardApiCall(() => _dio.delete('/notes/$id/permanent'));
  }

  Future<Note> archive(String id) {
    return guardApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>('/notes/$id/archive');
      return Note.fromJson(response.data!);
    });
  }

  Future<Note> unarchive(String id) {
    return guardApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>('/notes/$id/unarchive');
      return Note.fromJson(response.data!);
    });
  }
}

@riverpod
NoteRepository noteRepository(NoteRepositoryRef ref) => NoteRepository(ref.watch(apiClientProvider));
