import 'package:freezed_annotation/freezed_annotation.dart';

part 'note.freezed.dart';
part 'note.g.dart';

/// Espelha `noteResponseSchema`.
@freezed
class Note with _$Note {
  const factory Note({
    required String id,
    required String title,
    required String content,
    required List<String> tags,
    required bool isPinned,
    required int order,
    required bool isDeleted,
    required DateTime? deletedAt,
    required String? projectId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Note;

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);
}
