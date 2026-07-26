import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'notification_repository.dart';

part 'notification_center.g.dart';

const _refreshInterval = Duration(minutes: 2);

/// Vive enquanto o sino de notificações (`NotificationBell`) estiver
/// montado — na prática, a sessão autenticada inteira, já que ele mora na
/// `TopNavBar` (fora só da tela de login/splash). Atualiza sozinho a cada 2
/// minutos, além de sob demanda (`refresh`/`markAllRead`).
@riverpod
class NotificationCenter extends _$NotificationCenter {
  Timer? _timer;

  @override
  Future<NotificationListResult> build() async {
    _timer = Timer.periodic(_refreshInterval, (_) => refresh());
    ref.onDispose(() => _timer?.cancel());
    return ref.read(notificationRepositoryProvider).list();
  }

  Future<void> refresh() async {
    final result = await ref.read(notificationRepositoryProvider).list();
    state = AsyncData(result);
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null || current.unreadCount == 0) return;

    // Otimista — marca local antes da resposta do backend, pra não deixar
    // o badge "preso" no número antigo enquanto a chamada está em voo.
    state = AsyncData(
      NotificationListResult(
        notifications: [
          for (final notification in current.notifications)
            notification.copyWith(isRead: true),
        ],
        unreadCount: 0,
      ),
    );
    await ref.read(notificationRepositoryProvider).markAllRead();
  }
}
