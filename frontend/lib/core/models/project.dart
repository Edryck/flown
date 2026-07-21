import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';
part 'project.g.dart';

/// Espelha `projectResponseSchema`.
@freezed
class Project with _$Project {
  const factory Project({
    required String id,
    required String name,
    required String? description,
    required String color,
    required bool isArchived,
    required bool isDeleted,
    required DateTime? deletedAt,
    required int order,
    required String typeId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);
}
