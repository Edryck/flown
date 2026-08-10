import 'package:freezed_annotation/freezed_annotation.dart';

import 'local_date_time_converter.dart';

part 'app_notification.freezed.dart';
part 'app_notification.g.dart';

/// Espelha `notificationResponseSchema` (backend/src/schemas/notification.schema.ts).
/// Nome `AppNotification` (não `Notification`) de propósito — evita colidir
/// com a classe `Notification` embutida do próprio Flutter.
@freezed
class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    required String type,
    required Map<String, dynamic> payload,
    required String? taskId,
    required bool isRead,
    @LocalDateTimeConverter() required DateTime createdAt,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}
