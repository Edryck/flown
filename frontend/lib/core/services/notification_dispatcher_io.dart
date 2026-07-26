import 'package:intl/intl.dart';
import 'package:local_notifier/local_notifier.dart';

void showTaskDueNotification({
  required String title,
  required DateTime dueDate,
}) {
  final formattedDate = DateFormat('dd/MM HH:mm').format(dueDate);
  LocalNotification(
    title: 'Tarefa vencendo em breve',
    body: '"$title" vence em $formattedDate.',
  ).show();
}
