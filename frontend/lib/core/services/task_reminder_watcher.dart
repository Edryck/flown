import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/tasks/providers/task_list_controller.dart';
import 'notification_dispatcher.dart';

part 'task_reminder_watcher.g.dart';

// Mesma janela do lembrete por e-mail do backend (reminder.service.ts) - as
// duas notificações (nativa + e-mail) devem disparar juntas.
const _reminderWindowHours = 24;
const _checkInterval = Duration(minutes: 5);
const _notifiedTaskIdsKey = 'notified_task_ids';

/// Roda enquanto a sessão estiver autenticada (ver `main.dart`, que só
/// observa esse provider com o usuário logado) verificando tarefas vencendo
/// nas próximas 24h e disparando uma notificação nativa uma única vez por
/// tarefa. Independente do lembrete por e-mail (responsabilidade do
/// backend, roda mesmo com o app fechado de verdade) - esse aqui só existe
/// enquanto o processo do Flown está vivo (aberto ou na bandeja, Desktop).
/// Guarda quais tarefas já notificou em `SharedPreferences` pra sobreviver
/// a reinícios do app sem repetir notificação.
@riverpod
class TaskReminderWatcher extends _$TaskReminderWatcher {
  Timer? _timer;

  @override
  void build() {
    _timer = Timer.periodic(_checkInterval, (_) => _check());
    ref.onDispose(() => _timer?.cancel());
    _check();
  }

  Future<void> _check() async {
    final tasks = ref.read(taskListControllerProvider).valueOrNull;
    if (tasks == null) return;

    final prefs = await SharedPreferences.getInstance();
    final notified = (prefs.getStringList(_notifiedTaskIdsKey) ?? []).toSet();

    final now = DateTime.now();
    final threshold = now.add(const Duration(hours: _reminderWindowHours));

    for (final task in tasks) {
      final dueDate = task.dueDate;
      if (dueDate == null || task.completedAt != null) continue;
      if (notified.contains(task.id)) continue;
      if (dueDate.isBefore(now) || dueDate.isAfter(threshold)) continue;

      showTaskDueNotification(title: task.title, dueDate: dueDate);
      notified.add(task.id);
    }

    await prefs.setStringList(_notifiedTaskIdsKey, notified.toList());
  }
}
