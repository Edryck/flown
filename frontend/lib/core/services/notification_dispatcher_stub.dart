// Usado em qualquer target sem `dart:io` (hoje só Web) - sem equivalente de
// notificação nativa de SO implementado pra Web ainda.
void showTaskDueNotification({
  required String title,
  required DateTime dueDate,
}) {}
