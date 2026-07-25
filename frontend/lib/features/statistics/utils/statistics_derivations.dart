import 'package:flutter/material.dart';

import '../../../core/models/project.dart';
import '../../../core/models/task.dart';
import '../../projects/utils/project_stats.dart';
import '../providers/dashboard_stats_repository.dart';

const _monthAbbrev = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

const _dayAbbrev = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

/// "Pontuação de Produtividade" do protótipo (`Statistics.tsx`) não tem
/// nenhum equivalente no backend — é um número inventado lá (`85`, fixo).
/// Aqui vira um score de verdade (0-100), calculado a partir de 3 sinais
/// reais que o backend expõe: taxa de conclusão (peso 0.5), % de tasks
/// concluídas dentro do prazo (peso 0.3) e sequência de dias com foco
/// registrado, capada em 7 dias (peso 0.2). Fórmula própria — documentada
/// aqui pra poder ser ajustada, não é uma métrica do backend.
int computeProductivityScore(DashboardStats stats) {
  final completionRate = stats.productivity.completionRate.rate.clamp(0, 1);

  final due = stats.projectHealth.dueStatus;
  final completedWithDueDate = due.completedOnTime + due.completedLate;
  final onTimeRate = completedWithDueDate > 0
      ? due.completedOnTime / completedWithDueDate
      : 1.0;

  final streakFactor = (stats.focus.streak / 7).clamp(0, 1);

  final score =
      100 * (0.5 * completionRate + 0.3 * onTimeRate + 0.2 * streakFactor);
  return score.round().clamp(0, 100);
}

class MonthlyCount {
  const MonthlyCount({required this.label, required this.count});

  final String label;
  final int count;
}

/// Agrega `productivity.heatmap` (contagem por dia) em totais por mês —
/// vira o `BarChart` "Conclusão ao Longo do Tempo" do protótipo, mas com
/// dado real (o protótipo usa `monthlyCompletionData`, mock fixo). Cobre só
/// os meses dentro do `windowDays` da consulta (90 dias por padrão), não o
/// histórico inteiro.
List<MonthlyCount> aggregateHeatmapByMonth(List<HeatmapEntry> heatmap) {
  final counts = <String, int>{};
  final order = <String>[];
  for (final entry in heatmap) {
    final key =
        '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}';
    if (!counts.containsKey(key)) order.add(key);
    counts[key] = (counts[key] ?? 0) + entry.count;
  }
  order.sort();
  return [
    for (final key in order)
      MonthlyCount(
        label: _monthAbbrev[int.parse(key.split('-')[1]) - 1],
        count: counts[key]!,
      ),
  ];
}

class WeeklyStatusPoint {
  const WeeklyStatusPoint({
    required this.dayLabel,
    required this.todo,
    required this.inProgress,
    required this.inReview,
    required this.done,
  });

  final String dayLabel;
  final int todo;
  final int inProgress;
  final int inReview;
  final int done;
}

/// "Atividade Semanal" do protótipo (`weeklyProductivityData`, mock fixo,
/// linhas "Criado"/"Concluído") não tem endpoint equivalente — vira aqui a
/// contagem de tasks tocadas (`updatedAt` cai naquele dia) por status atual
/// (A Fazer/Em Andamento/Em Revisão/Concluído), calculada client-side a
/// partir da lista de tasks já carregada. É um proxy de "atividade": o
/// backend não guarda histórico de mudança de status, só o status atual —
/// não dá pra saber em que status uma task estava num dia específico no
/// passado, só que ela foi tocada nesse dia e onde está agora.
///
/// Sempre começa no domingo da semana atual (não "últimos 7 dias corridos")
/// — pode incluir dias futuros da semana (ainda sem atividade, contagem 0).
///
/// Usa os literais `'Todo'`/`'In Progress'`/`'In Review'`/`'Done'`
/// (convenção dos `ProjectType` seedados, mesmo atalho documentado em
/// `focus_screen.dart`), não os labels em português mostrados no gráfico.
List<WeeklyStatusPoint> computeWeeklyStatusActivity(List<Task> tasks) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final sunday = todayDate.subtract(Duration(days: todayDate.weekday % 7));

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  return [
    for (var i = 0; i < 7; i++)
      () {
        final day = sunday.add(Duration(days: i));
        final touchedThatDay = tasks.where((t) => sameDay(t.updatedAt, day));
        return WeeklyStatusPoint(
          dayLabel: _dayAbbrev[day.weekday % 7],
          todo: touchedThatDay.where((t) => t.status == 'Todo').length,
          inProgress: touchedThatDay
              .where((t) => t.status == 'In Progress')
              .length,
          inReview: touchedThatDay.where((t) => t.status == 'In Review').length,
          done: touchedThatDay.where((t) => t.status == 'Done').length,
        );
      }(),
  ];
}

class InsightCardData {
  const InsightCardData({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
}

/// Substitui os 4 cards de texto fixo do painel "Insights & Recomendações"
/// do protótipo por insights de verdade, gerados a partir de
/// `DashboardStats` — o protótipo nunca calcula nada aqui, é texto estático
/// no componente.
List<InsightCardData> buildInsights(
  DashboardStats stats, {
  required Color positiveColor,
  required Color warningColor,
}) {
  final ratePercent = (stats.productivity.completionRate.rate * 100).round();
  final peak = stats.focus.peakHour.peakHour;
  final streak = stats.focus.streak;
  final overdue = stats.projectHealth.dueStatus.overdue;

  return [
    InsightCardData(
      icon: Icons.trending_up,
      color: positiveColor,
      title: ratePercent >= 50 ? 'Bom progresso!' : 'Foco na conclusão',
      description:
          'Você concluiu $ratePercent% das ${stats.productivity.completionRate.created} tarefas criadas nos últimos '
          '${stats.windowDays} dias.',
    ),
    InsightCardData(
      icon: Icons.schedule,
      color: const Color(0xFF3D6FA6),
      title: 'Horário mais produtivo',
      description: peak != null
          ? 'Você conclui mais tarefas por volta das ${peak.toString().padLeft(2, '0')}h.'
          : 'Ainda não há dados suficientes pra identificar seu horário mais produtivo.',
    ),
    InsightCardData(
      icon: Icons.local_fire_department,
      color: const Color(0xFFB2560D),
      title: streak > 0 ? 'Sequência ativa' : 'Comece uma sequência',
      description: streak > 0
          ? 'Você está há $streak dia${streak == 1 ? '' : 's'} seguido${streak == 1 ? '' : 's'} com foco registrado.'
          : 'Use o Modo Foco hoje pra começar uma sequência de dias produtivos.',
    ),
    InsightCardData(
      icon: overdue > 0 ? Icons.error_outline : Icons.verified_outlined,
      color: overdue > 0 ? warningColor : const Color(0xFF7A5AA6),
      title: overdue > 0
          ? '$overdue tarefa${overdue == 1 ? '' : 's'} atrasada${overdue == 1 ? '' : 's'}'
          : 'Tudo em dia',
      description: overdue > 0
          ? 'Vale revisar os prazos das tarefas atrasadas.'
          : 'Nenhuma tarefa atrasada no momento — mandou bem!',
    ),
  ];
}

class ProjectBreakdownEntry {
  const ProjectBreakdownEntry({
    required this.projectName,
    required this.taskCount,
    required this.progress,
    required this.isOverdue,
  });

  final String projectName;
  final int taskCount;

  /// 0-100.
  final int progress;
  final bool isOverdue;
}

/// "Tarefas por Projeto" das Estatísticas — reaproveita `computeProjectStats`
/// (mesma lógica usada nos cards da tela Projetos) em vez de recalcular
/// progresso/atraso do zero. `tasks` deve já estar filtrada a top-level
/// (sem subtasks); projetos sem nenhuma task não entram no resultado.
List<ProjectBreakdownEntry> computeProjectBreakdown(
  List<Task> tasks,
  List<Project> projects,
) {
  final tasksByProject = <String, List<Task>>{};
  for (final task in tasks) {
    final projectId = task.projectId;
    if (projectId == null) continue;
    (tasksByProject[projectId] ??= []).add(task);
  }

  final entries = [
    for (final project in projects)
      if (tasksByProject[project.id] case final projectTasks?)
        () {
          final stats = computeProjectStats(projectTasks);
          return ProjectBreakdownEntry(
            projectName: project.name,
            taskCount: stats.taskCount,
            progress: stats.progress,
            isOverdue: stats.isOverdue,
          );
        }(),
  ];
  entries.sort((a, b) => b.taskCount.compareTo(a.taskCount));
  return entries;
}
