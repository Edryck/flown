import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notifications/providers/notification_center.dart';
import '../../features/notifications/providers/notification_repository.dart';
import '../../features/tasks/providers/task_list_controller.dart';
import '../../features/tasks/utils/task_status_colors.dart';
import '../../features/tasks/widgets/task_view_dialog.dart';
import '../models/app_notification.dart';
import '../models/task.dart';

const _panelWidth = 340.0;

class _NotificationDisplay {
  const _NotificationDisplay({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

/// Traduz `type`+`payload` (dados estruturados, em inglês, vindos do
/// backend — mesma convenção de `Task.status`) numa frase em português —
/// só o frontend formata texto pro usuário, o backend nunca manda frase
/// pronta.
_NotificationDisplay _formatNotification(AppNotification notification) {
  final payload = notification.payload;
  switch (notification.type) {
    case 'status_changed':
      final oldStatus = payload['oldStatus'] as String? ?? '';
      final newStatus = payload['newStatus'] as String? ?? '';
      return _NotificationDisplay(
        icon: Icons.swap_horiz,
        color: const Color(0xFF3D6FA6),
        title: payload['taskTitle'] as String? ?? '',
        subtitle:
            '${statusLabelPtBr(oldStatus)} → ${statusLabelPtBr(newStatus)}',
      );

    case 'due_soon':
      final thresholdHours = (payload['thresholdHours'] as num?)?.toInt() ?? 0;
      return _NotificationDisplay(
        icon: Icons.schedule_outlined,
        color: const Color(0xFFB2560D),
        title: payload['taskTitle'] as String? ?? '',
        subtitle: thresholdHours <= 1
            ? 'Vence em até 1 hora'
            : 'Vence em até $thresholdHours horas',
      );

    case 'productivity_summary':
      final period = payload['period'] as String? ?? '';
      final completedThis =
          (payload['completedThisPeriod'] as num?)?.toInt() ?? 0;
      final completedLast =
          (payload['completedLastPeriod'] as num?)?.toInt() ?? 0;
      final percentChange = (payload['percentChange'] as num?)?.toInt();
      final diff = completedThis - completedLast;
      final periodLabel = period == 'weekly' ? 'semana passada' : 'mês passado';
      final diffLabel = diff == 0
          ? 'igual ao período anterior'
          : diff > 0
          ? '$diff a mais'
          : '${diff.abs()} a menos';
      final percentLabel = percentChange == null
          ? ''
          : percentChange >= 0
          ? ' (+$percentChange%)'
          : ' ($percentChange%)';
      return _NotificationDisplay(
        icon: Icons.insights_outlined,
        color: const Color(0xFF7A5AA6),
        title: 'Resumo de produtividade ($periodLabel)',
        subtitle: 'Concluiu $completedThis tarefas — $diffLabel$percentLabel',
      );

    default:
      return const _NotificationDisplay(
        icon: Icons.notifications_outlined,
        color: Color(0xFF6B7B8F),
        title: 'Notificação',
        subtitle: '',
      );
  }
}

String _formatElapsed(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inDays >= 1) {
    return 'há ${diff.inDays} dia${diff.inDays == 1 ? '' : 's'}';
  }
  if (diff.inHours >= 1) {
    return 'há ${diff.inHours} hora${diff.inHours == 1 ? '' : 's'}';
  }
  if (diff.inMinutes >= 1) {
    return 'há ${diff.inMinutes} minuto${diff.inMinutes == 1 ? '' : 's'}';
  }
  return 'agora mesmo';
}

/// Sino de notificações da `TopNavBar` — mesmo mecanismo de dropdown do
/// campo de busca global (`OverlayPortal` + `CompositedTransformFollower`),
/// ancorado no próprio ícone em vez de um campo. Sem tela cheia/rota
/// própria de propósito — o dropdown já é a "central de notificações".
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key, this.anchorAbove = false});

  /// `true` quando o sino fica perto do fundo da tela (rodapé da
  /// `AppSidebar`) - sem isso, o painel tentava abrir pra baixo e pra
  /// esquerda a partir de um ícone que já está colado na borda inferior
  /// esquerda, saindo inteiro da área visível (parecia que o clique não
  /// fazia nada). No `TopNavBar` (ícone no topo, com espaço sobrando embaixo
  /// e à esquerda) o padrão original continua servindo bem.
  final bool anchorAbove;

  static const _groupId = 'top-nav-notifications';

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  final _layerLink = LayerLink();
  final _overlayController = OverlayPortalController();

  void _toggle() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    } else {
      _overlayController.show();
      ref.read(notificationCenterProvider.notifier).refresh();
    }
  }

  void _openTask(String taskId) {
    _overlayController.hide();
    final tasks =
        ref.read(taskListControllerProvider).valueOrNull ?? const <Task>[];
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task != null) showTaskViewDialog(context, task: task);
  }

  @override
  Widget build(BuildContext context) {
    final result =
        ref.watch(notificationCenterProvider).valueOrNull ??
        NotificationListResult.empty;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TapRegion(
        groupId: NotificationBell._groupId,
        onTapOutside: (_) => _overlayController.hide(),
        child: OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: (context) => CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            // `targetAnchor`/`followerAnchor` nos dois cantos direitos —
            // o Flutter calcula o alinhamento sozinho a partir do tamanho
            // real do ícone, sem precisar de um offset manual tipo
            // `-(panelWidth - iconWidth)` (que dependia de eu acertar a
            // largura exata do IconButton renderizado, fácil de errar e
            // empurrar o painel pra fora da área visível da janela).
            // Com `anchorAbove`, inverte pra cima/direita - o ícone no
            // rodapé da sidebar não tem espaço embaixo nem à esquerda.
            targetAnchor: widget.anchorAbove ? Alignment.topLeft : Alignment.bottomRight,
            followerAnchor: widget.anchorAbove ? Alignment.bottomLeft : Alignment.topRight,
            offset: Offset(0, widget.anchorAbove ? -8 : 8),
            child: TapRegion(
              groupId: NotificationBell._groupId,
              child: Align(
                alignment: widget.anchorAbove ? Alignment.bottomLeft : Alignment.topRight,
                child: _NotificationPanel(
                  notifications: result.notifications,
                  onTapNotification: (n) {
                    if (n.taskId != null) _openTask(n.taskId!);
                  },
                  onMarkAllRead: () => ref
                      .read(notificationCenterProvider.notifier)
                      .markAllRead(),
                ),
              ),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                // Sem `tooltip` de propósito — o Tooltip usa um overlay
                // por baixo dos panos, e colide com o
                // `CompositedTransformFollower` do dropdown quando o mouse
                // passa por cima pra clicar (erro real de layout visto em
                // teste: "paint transform cannot be reliably computed
                // because of RenderFollowerLayer(s)").
                onPressed: _toggle,
                icon: const Icon(Icons.notifications_outlined, size: 20),
              ),
              if (result.unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${result.unreadCount}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onError,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({
    required this.notifications,
    required this.onTapNotification,
    required this.onMarkAllRead,
  });

  final List<AppNotification> notifications;
  final ValueChanged<AppNotification> onTapNotification;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasUnread = notifications.any((n) => !n.isRead);

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: theme.cardTheme.color ?? colorScheme.surface,
      child: Container(
        width: _panelWidth,
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notificações',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Sem `tooltip` de propósito — qualquer Tooltip dentro
                  // do conteúdo do painel, que já mora num
                  // `CompositedTransformFollower`, colide com o mesmo bug
                  // de layout do ícone que abre o dropdown (ver
                  // comentário no IconButton do sino, mais abaixo).
                  if (hasUnread)
                    IconButton(
                      onPressed: onMarkAllRead,
                      icon: const Icon(Icons.done_all, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nenhuma notificação por enquanto',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final notification in notifications)
                        _NotificationTile(
                          notification: notification,
                          onTap: () => onTapNotification(notification),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final display = _formatNotification(notification);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: notification.isRead
              ? null
              : colorScheme.primary.withValues(alpha: 0.05),
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(display.icon, size: 18, color: display.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    display.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  if (display.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      display.subtitle,
                      style: TextStyle(color: display.color, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatElapsed(notification.createdAt),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
