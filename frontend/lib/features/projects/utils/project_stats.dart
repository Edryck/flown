import '../../../core/models/task.dart';

/// Métricas de um projeto derivadas das tasks vinculadas a ele — decisão
/// tomada ao traduzir `screens/Projects.tsx`
/// (docs/prototype/screens/projects.md): o `Project` real do backend não
/// guarda `status`/`progress`/`dueDate` (só o mock do protótipo tem esses
/// campos), então tudo isso vem das tasks do projeto em vez de ler direto
/// do `Project`. `tasks` deve ser a lista já filtrada por `projectId`.
class ProjectStats {
  const ProjectStats({
    required this.taskCount,
    required this.progress,
    required this.isDone,
    required this.isOverdue,
    required this.nextDueDate,
  });

  final int taskCount;

  /// % de tasks com `completedAt != null`. 0 se o projeto não tem tasks.
  final int progress;

  /// Todas as tasks concluídas, e há pelo menos uma. Equivalente ao
  /// `status === 'done'` do mock, mas derivado.
  final bool isDone;

  /// Alguma task não concluída com prazo vencido.
  final bool isOverdue;

  /// Prazo mais próximo entre as tasks não concluídas (equivalente ao
  /// `project.dueDate` do mock, que não existe no `Project` real).
  final DateTime? nextDueDate;

  static const empty = ProjectStats(taskCount: 0, progress: 0, isDone: false, isOverdue: false, nextDueDate: null);
}

ProjectStats computeProjectStats(Iterable<Task> projectTasks) {
  final tasks = projectTasks.toList();
  if (tasks.isEmpty) return ProjectStats.empty;

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);

  final doneCount = tasks.where((t) => t.completedAt != null).length;
  final pending = tasks.where((t) => t.completedAt == null);

  DateTime? nextDueDate;
  var isOverdue = false;
  for (final task in pending) {
    final due = task.dueDate;
    if (due == null) continue;
    final dueDate = DateTime(due.year, due.month, due.day);
    if (dueDate.isBefore(todayDate)) isOverdue = true;
    if (nextDueDate == null || dueDate.isBefore(nextDueDate)) nextDueDate = dueDate;
  }

  return ProjectStats(
    taskCount: tasks.length,
    progress: ((doneCount / tasks.length) * 100).round(),
    isDone: doneCount == tasks.length,
    isOverdue: isOverdue,
    nextDueDate: nextDueDate,
  );
}
