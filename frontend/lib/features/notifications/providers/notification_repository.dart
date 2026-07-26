import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/app_notification.dart';

part 'notification_repository.g.dart';

class NotificationListResult {
  const NotificationListResult({
    required this.notifications,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int unreadCount;

  static const empty = NotificationListResult(
    notifications: [],
    unreadCount: 0,
  );
}

/// Fala com `/notifications`. Feed de eventos (mudança de status, prazo se
/// aproximando, resumo de produtividade) gerado pelo backend — ver
/// `notification_bell.dart` pra como cada tipo vira frase em português.
class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;

  Future<NotificationListResult> list({int limit = 20}) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/notifications',
        queryParameters: {'limit': limit},
      );
      final data = response.data!;
      return NotificationListResult(
        notifications: (data['notifications'] as List)
            .map(
              (item) => AppNotification.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        unreadCount: data['unreadCount'] as int,
      );
    });
  }

  Future<void> markAllRead() {
    return guardApiCall(() => _dio.post('/notifications/read-all'));
  }
}

@riverpod
NotificationRepository notificationRepository(NotificationRepositoryRef ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
}
