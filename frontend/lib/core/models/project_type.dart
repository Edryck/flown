import 'package:freezed_annotation/freezed_annotation.dart';

part 'project_type.freezed.dart';
part 'project_type.g.dart';

/// Espelha `projectTypeResponseSchema`. `availableStatus` e a lista de
/// status validos pras tasks de um projeto desse tipo — a ORDEM da lista e
/// usada pra escolher a cor do status (ver AppSemanticColors.statusColorAt),
/// nao o nome do status.
@freezed
class ProjectType with _$ProjectType {
  const factory ProjectType({
    required String id,
    required String name,
    required List<String> availableStatus,
  }) = _ProjectType;

  factory ProjectType.fromJson(Map<String, dynamic> json) => _$ProjectTypeFromJson(json);
}
