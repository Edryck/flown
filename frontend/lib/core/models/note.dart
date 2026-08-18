import 'package:freezed_annotation/freezed_annotation.dart';

import 'local_date_time_converter.dart';

part 'note.freezed.dart';
part 'note.g.dart';

/// Espelha `noteResponseSchema`.
@freezed
class Note with _$Note {
  const factory Note({
    required String id,
    required String title,
    required String content,
    required String color,
    required List<String> tags,
    required bool isPinned,
    required int order,
    required bool isDeleted,
    @NullableLocalDateTimeConverter() required DateTime? deletedAt,
    required bool isArchived,
    @NullableLocalDateTimeConverter() required DateTime? archivedAt,
    required String? projectId,
    @LocalDateTimeConverter() required DateTime createdAt,
    @LocalDateTimeConverter() required DateTime updatedAt,
  }) = _Note;

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);
}
