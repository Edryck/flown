import 'package:freezed_annotation/freezed_annotation.dart';

import 'focus_session_type.dart';
import 'local_date_time_converter.dart';

part 'focus_session.freezed.dart';
part 'focus_session.g.dart';

/// Espelha `focusSessionResponseSchema`. Sem soft delete — o model
/// `FocusSession` no Prisma nao tem `isDeleted`/`deletedAt` (log 05/06 do
/// backend), `DELETE /sessions/:id` e exclusao real.
@freezed
class FocusSession with _$FocusSession {
  const factory FocusSession({
    required String id,
    required FocusSessionKind type,
    required int durationSeconds,
    @LocalDateTimeConverter() required DateTime startedAt,
    @NullableLocalDateTimeConverter() required DateTime? completedAt,
    required String? taskId,
    @LocalDateTimeConverter() required DateTime createdAt,
  }) = _FocusSession;

  factory FocusSession.fromJson(Map<String, dynamic> json) => _$FocusSessionFromJson(json);
}
