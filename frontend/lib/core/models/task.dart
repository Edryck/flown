import 'package:freezed_annotation/freezed_annotation.dart';

import 'checklist_item.dart';
import 'local_date_time_converter.dart';
import 'task_priority.dart';

part 'task.freezed.dart';
part 'task.g.dart';

/// Espelha `taskResponseSchema`.
///
/// `status` e `String` livre (nao enum) de proposito — e validado
/// dinamicamente pelo backend contra `ProjectType.availableStatus`, entao o
/// client nao pode assumir um conjunto fixo de valores (log 02/03 do
/// backend). `priority` esse sim e fixo (`TaskPriority`).
@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String title,
    required String? description,
    required String status,
    required TaskPriority priority,
    @NullableLocalDateTimeConverter() required DateTime? dueDate,
    required int? progress,
    required String? estimatedTime,
    required List<String> tags,
    required List<ChecklistItem> checklist,
    required int order,
    required bool isDeleted,
    @NullableLocalDateTimeConverter() required DateTime? deletedAt,
    required bool isArchived,
    @NullableLocalDateTimeConverter() required DateTime? archivedAt,
    @NullableLocalDateTimeConverter() required DateTime? completedAt,
    required String? projectId,
    required String? parentTaskId,
    @LocalDateTimeConverter() required DateTime createdAt,
    @LocalDateTimeConverter() required DateTime updatedAt,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}
