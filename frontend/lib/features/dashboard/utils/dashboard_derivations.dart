import 'package:flutter/material.dart';

import '../../../core/models/note.dart';
import '../../../core/models/task.dart';
import '../../../core/models/task_priority.dart';
import '../../statistics/providers/dashboard_stats_repository.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// 4 números do resumo diário do protótipo (`Dashboard.tsx`), recalculados
/// aqui a partir da lista de tasks real em vez de `mockTasks` — usa
/// `completedAt` (não `status !== 'done'`) pra "concluída", mesma convenção
/// de `TasksTableView._isOverdue` (o backend não tem status fixo de
/// conclusão, é dinâmico por `ProjectType`, mas sempre grava `completedAt`).
int countDueToday(List<Task> tasks) {
  final today = _dateOnly(DateTime.now());
  return tasks.where((t) => t.completedAt == null && t.dueDate != null && _isSameDay(_dateOnly(t.dueDate!), today)).length;
}

int countOverdue(List<Task> tasks) {
  final today = _dateOnly(DateTime.now());
  return tasks.where((t) => t.completedAt == null && t.dueDate != null && _dateOnly(t.dueDate!).isBefore(today)).length;
}

int countCompletedToday(List<Task> tasks) {
  final today = _dateOnly(DateTime.now());
  return tasks.where((t) => t.completedAt != null && _isSameDay(_dateOnly(t.completedAt!), today)).length;
}

int countInProgress(List<Task> tasks) => tasks.where((t) => t.status == 'In Progress').length;

/// Tasks criadas na semana atual (domingo a hoje) - mesma janela de
/// [computeWeeklyProductivitySummary], pro card "Visão Geral" mostrar
/// criadas/concluídas lado a lado com a mesma referência de tempo.
int countCreatedThisWeek(List<Task> tasks) {
  final today = _dateOnly(DateTime.now());
  final sunday = today.subtract(Duration(days: today.weekday % 7));
  return tasks.where((t) => !_dateOnly(t.createdAt).isBefore(sunday)).length;
}

class StatusBreakdown {
  const StatusBreakdown({
    required this.todo,
    required this.inProgress,
    required this.overdue,
    required this.completed,
  });

  final int todo;
  final int inProgress;
  final int overdue;
  final int completed;
}

/// Partição mutuamente exclusiva de todas as tasks em 4 grupos fixos (A
/// Fazer/Em Andamento/Atrasada/Concluída) — diferente de `byStatus` da tela
/// de Estatísticas, que particiona pelo `status` dinâmico de cada
/// `ProjectType` (não dá pra montar um "A Fazer" universal a partir disso,
/// já que o nome do status varia por tipo de projeto). Aqui a ordem de
/// prioridade evita contar a mesma task 2x (ex: atrasada E "In Progress" ao
/// mesmo tempo conta só como atrasada): concluída > atrasada > em andamento
/// > a fazer.
StatusBreakdown computeStatusBreakdown(List<Task> tasks) {
  var todo = 0;
  var inProgress = 0;
  var overdue = 0;
  var completed = 0;
  final today = _dateOnly(DateTime.now());

  for (final task in tasks) {
    if (task.completedAt != null) {
      completed++;
    } else if (task.dueDate != null && _dateOnly(task.dueDate!).isBefore(today)) {
      overdue++;
    } else if (task.status == 'In Progress') {
      inProgress++;
    } else {
      todo++;
    }
  }

  return StatusBreakdown(todo: todo, inProgress: inProgress, overdue: overdue, completed: completed);
}

/// "Foco Atual" do protótipo: `Array.find` (primeira task só) com
/// `status === 'in_progress' && priority === 'high'` — mantido como critério
/// único de propósito (docs/prototype/screens/dashboard.md, seção
/// "Observações"): é o comportamento documentado do mock, não uma limitação
/// acidental.
Task? findCurrentFocusTask(List<Task> tasks) {
  for (final task in tasks) {
    if (task.status == 'In Progress' && task.priority == TaskPriority.high) return task;
  }
  return null;
}

const Map<TaskPriority, int> _priorityOrder = {TaskPriority.high: 0, TaskPriority.medium: 1, TaskPriority.low: 2};

/// Até [limit] tasks não concluídas, ordenadas por prioridade (alta→baixa) —
/// mesmo filtro+sort do protótipo, mas por `completedAt` em vez de
/// `status !== 'done'` (ver [[countDueToday]]).
List<Task> computeUpcomingTasks(List<Task> tasks, {int limit = 6}) {
  final pending = tasks.where((t) => t.completedAt == null).toList()
    ..sort((a, b) => _priorityOrder[a.priority]!.compareTo(_priorityOrder[b.priority]!));
  return pending.take(limit).toList();
}

enum ActivityType { taskCompleted, taskCreated, noteCreated }

class ActivityEntry {
  const ActivityEntry({required this.type, required this.title, required this.description, required this.timestamp});

  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;

  IconData get icon => switch (type) {
        ActivityType.taskCompleted => Icons.check_circle_outline,
        ActivityType.taskCreated => Icons.add_circle_outline,
        ActivityType.noteCreated => Icons.description_outlined,
      };
}

/// "Atividade Recente" do protótipo (`mockActivities`, mock fixo com 4 tipos
/// incluindo `status_changed`) não tem log de atividade equivalente no
/// backend (nenhuma tabela guarda histórico de mudanças). Aqui vira um feed
/// sintetizado a partir de 2 sinais reais que existem (`Task.createdAt`/
/// `completedAt`, `Note.createdAt`) — sem `status_changed`, que exigiria
/// histórico que o backend não guarda.
List<ActivityEntry> computeRecentActivity(List<Task> tasks, List<Note> notes, {int limit = 6}) {
  final entries = <ActivityEntry>[
    for (final task in tasks) ...[
      ActivityEntry(type: ActivityType.taskCreated, title: 'Tarefa criada', description: task.title, timestamp: task.createdAt),
      if (task.completedAt != null)
        ActivityEntry(
          type: ActivityType.taskCompleted,
          title: 'Tarefa concluída',
          description: task.title,
          timestamp: task.completedAt!,
        ),
    ],
    for (final note in notes)
      ActivityEntry(type: ActivityType.noteCreated, title: 'Anotação criada', description: note.title, timestamp: note.createdAt),
  ];
  entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return entries.take(limit).toList();
}

const _dayAbbrev = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

class WeeklyCompletionPoint {
  const WeeklyCompletionPoint({required this.dayLabel, required this.count});

  final String dayLabel;
  final int count;
}

class WeeklyProductivitySummary {
  const WeeklyProductivitySummary({required this.points, required this.total, required this.dailyAverage});

  final List<WeeklyCompletionPoint> points;
  final int total;
  final double dailyAverage;
}

/// "Esta Semana" do protótipo usa `weeklyProductivityData` mock + 2 números
/// hardcoded no JSX ("59 tarefas", "8.4 tarefas" — texto literal, não
/// calculado, ver docs/prototype/screens/dashboard.md). Aqui os 2 números
/// viram reais (soma/média dos pontos), extraídos de `DashboardStats.
/// productivity.heatmap` (mesma fonte que a `StatisticsScreen` usa), filtrado
/// pra semana atual (domingo a hoje).
WeeklyProductivitySummary computeWeeklyProductivitySummary(List<HeatmapEntry> heatmap) {
  final today = _dateOnly(DateTime.now());
  final sunday = today.subtract(Duration(days: today.weekday % 7));
  final countsByDay = {for (final entry in heatmap) _dateOnly(entry.date): entry.count};

  final points = <WeeklyCompletionPoint>[];
  for (var i = 0; i < 7; i++) {
    final day = sunday.add(Duration(days: i));
    points.add(WeeklyCompletionPoint(dayLabel: _dayAbbrev[day.weekday % 7], count: countsByDay[day] ?? 0));
  }

  final total = points.fold<int>(0, (sum, p) => sum + p.count);
  return WeeklyProductivitySummary(points: points, total: total, dailyAverage: total / 7);
}