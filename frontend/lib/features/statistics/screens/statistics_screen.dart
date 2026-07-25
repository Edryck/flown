import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task_priority.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../../core/widgets/screen_gradient_backdrop.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../tasks/providers/task_list_controller.dart';
import '../../tasks/utils/task_hierarchy.dart';
import '../../tasks/utils/task_status_colors.dart';
import '../providers/dashboard_stats_repository.dart';
import '../utils/statistics_derivations.dart';
import '../widgets/completion_heatmap.dart';

/// Tela de estatísticas — tradução de Statistics.tsx
/// (docs/prototype/screens/statistics.md), mas redesenhada em cima de dados
/// reais (`GET /dashboard/stats`) em vez dos números/gráficos 100%
/// hardcoded do protótipo (`completionRate = 78`, `monthlyCompletionData`
/// mock, etc.). Ver `dashboard_stats_repository.dart` e
/// `statistics_derivations.dart` pra como cada métrica é calculada/de onde
/// vem.
///
/// Duas janelas de dados diferentes, de propósito: `dashboardStatsProvider`
/// (90 dias, "desempenho recente" — cards + pizza de distribuição) e
/// `annualDashboardStatsProvider` (desde 1º de janeiro do ano corrente —
/// heatmap + gráfico mensal, que mostram o ano calendário inteiro).
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final annualStatsAsync = ref.watch(annualDashboardStatsProvider);
    final tasksAsync = ref.watch(taskListControllerProvider);
    final projectsAsync = ref.watch(projectListControllerProvider);

    return ScreenGradientBackdrop(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estatísticas',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Rastreie sua produtividade e desempenho',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text('Erro ao carregar estatísticas: $error'),
                ),
              ),
              data: (stats) {
                // Subtarefas não contam como tasks nas Estatísticas — só as
                // de nível superior.
                final tasks = topLevelTasks(tasksAsync.valueOrNull ?? const []);
                final annualHeatmap =
                    annualStatsAsync.valueOrNull?.productivity.heatmap ??
                    const <HeatmapEntry>[];

                final monthly = aggregateHeatmapByMonth(annualHeatmap);
                // "Até 7 meses" de propósito — o heatmap por trás cobre o ano
                // inteiro, mas ao lado da pizza (mais estreito) o gráfico de
                // barras fica ilegível com os 12 meses; os 7 mais recentes
                // bastam pra mostrar tendência sem espremer demais.
                final recentMonthly = monthly.length > 7
                    ? monthly.sublist(monthly.length - 7)
                    : monthly;
                final projectBreakdown = computeProjectBreakdown(
                  tasks,
                  projectsAsync.valueOrNull ?? const [],
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricsRow(stats: stats),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final barChart = _ChartCard(
                          title: 'Conclusão ao Longo do Tempo',
                          subtitle:
                              'Total de conclusões por mês (últimos ${recentMonthly.length} meses)',
                          child: _MonthlyBarChart(data: recentMonthly),
                        );
                        final pieChart = _ChartCard(
                          title: 'Distribuição de Tarefas',
                          subtitle: 'Tarefas atuais por status',
                          child: _StatusPieChart(
                            byStatus: stats.projectHealth.distribution.byStatus,
                          ),
                        );

                        // Lado a lado com a MESMA largura e altura (a divisão
                        // fica bem no meio) — só empilha em telas estreitas,
                        // onde não cabem os dois cards um do lado do outro.
                        if (constraints.maxWidth < 700) {
                          return Column(
                            children: [
                              barChart,
                              const SizedBox(height: 24),
                              pieChart,
                            ],
                          );
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: barChart),
                              const SizedBox(width: 24),
                              Expanded(child: pieChart),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final priorityChart = _ChartCard(
                          title: 'Distribuição por Prioridade',
                          subtitle: 'Tarefas atuais por prioridade',
                          child: _PriorityPieChart(
                            byPriority:
                                stats.projectHealth.distribution.byPriority,
                          ),
                        );
                        final peakHourChart = _ChartCard(
                          title: 'Horário de Conclusão',
                          subtitle: stats.focus.peakHour.peakHour != null
                              ? 'Tarefas concluídas por horário do dia (pico às ${stats.focus.peakHour.peakHour}h)'
                              : 'Tarefas concluídas por horário do dia',
                          child: _PeakHourChart(peakHour: stats.focus.peakHour),
                        );

                        if (constraints.maxWidth < 700) {
                          return Column(
                            children: [
                              priorityChart,
                              const SizedBox(height: 24),
                              peakHourChart,
                            ],
                          );
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: priorityChart),
                              const SizedBox(width: 24),
                              Expanded(child: peakHourChart),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _ChartCard(
                      title: 'Tarefas por Projeto',
                      subtitle: 'Progresso e quantidade de tarefas por projeto',
                      child: _ProjectBreakdownChart(entries: projectBreakdown),
                    ),
                    const SizedBox(height: 24),
                    _ChartCard(
                      title: 'Atividade Semanal',
                      subtitle:
                          'Tarefas tocadas por dia, por status atual (semana começando no domingo)',
                      child: _WeeklyActivityChart(
                        data: computeWeeklyStatusActivity(tasks),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ChartCard(
                      title: 'Mapa de Conclusões',
                      subtitle:
                          'Tarefas concluídas por dia em ${DateTime.now().year}',
                      child: CompletionHeatmap(entries: annualHeatmap),
                    ),
                    const SizedBox(height: 24),
                    _InsightsPanel(stats: stats),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final ratePercent = (stats.productivity.completionRate.rate * 100).round();
    final avgHours = stats.productivity.averageTimeToCompleteByPriority.values
        .whereType<double>()
        .toList();
    final avgDaysLabel = avgHours.isEmpty
        ? '—'
        : '${(avgHours.reduce((a, b) => a + b) / avgHours.length / 24).toStringAsFixed(1)} dias';
    final score = computeProductivityScore(stats);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : (constraints.maxWidth >= 500 ? 2 : 1);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.6,
          children: [
            MetricCard(
              title: 'Taxa de Conclusão',
              value: '$ratePercent%',
              icon: Icons.track_changes_outlined,
              iconColor: const Color(0xFF2B6CB0),
              subtitle:
                  '${stats.productivity.completionRate.completed} de ${stats.productivity.completionRate.created} tarefas',
            ),
            MetricCard(
              title: 'Total Concluído',
              value: '${stats.productivity.completionRate.completed}',
              icon: Icons.emoji_events_outlined,
              iconColor: const Color(0xFF2E7D51),
              subtitle: 'Últimos ${stats.windowDays} dias',
            ),
            MetricCard(
              title: 'Tempo Médio',
              value: avgDaysLabel,
              icon: Icons.hourglass_bottom_outlined,
              iconColor: const Color(0xFFB2560D),
              subtitle: 'Média entre prioridades com dados',
            ),
            MetricCard(
              title: 'Pontuação de Produtividade',
              value: '$score',
              icon: Icons.insights_outlined,
              iconColor: const Color(0xFF7A5AA6),
              subtitle:
                  'Sequência de ${stats.focus.streak} dia${stats.focus.streak == 1 ? '' : 's'}',
            ),
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  const _MonthlyBarChart({required this.data});

  final List<MonthlyCount> data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (data.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(child: Text('Sem dados no período')),
      );
    }

    final maxCount = data.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          maxY: (maxCount == 0 ? 1 : maxCount) * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                // `interval: 1` de propósito — sem isso o fl_chart escolhe
                // o intervalo sozinho com base na largura disponível, e
                // pede `getTitlesWidget` pra MUITO mais valores do que os
                // índices inteiros que existem em `data` (rótulos
                // repetidos/quebrados no eixo).
                interval: 1,
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= data.length || index != value)
                    return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data[index].label,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].count.toDouble(),
                    color: colorScheme.primary,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPieChart extends StatelessWidget {
  const _StatusPieChart({required this.byStatus});

  final Map<String, int> byStatus;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;

    if (byStatus.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(child: Text('Sem tarefas ainda')),
      );
    }

    final entries = byStatus.entries.toList();

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: semantic.statusColorAt(i),
                    radius: 40,
                    title: '${entries[i].value}',
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (var i = 0; i < entries.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: semantic.statusColorAt(i),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${statusLabelPtBr(entries[i].key)}: ${entries[i].value}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _PriorityPieChart extends StatelessWidget {
  const _PriorityPieChart({required this.byPriority});

  final Map<String, int> byPriority;

  Color _colorOf(AppSemanticColors semantic, TaskPriority priority) =>
      switch (priority) {
        TaskPriority.high => semantic.priorityHigh,
        TaskPriority.medium => semantic.priorityMedium,
        TaskPriority.low => semantic.priorityLow,
      };

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    // Ordem de severidade (Alta -> Baixa) em vez da ordem de inserção do
    // Map, que vem do backend sem garantia de ordem.
    const order = [TaskPriority.high, TaskPriority.medium, TaskPriority.low];
    final entries = [
      for (final priority in order)
        if ((byPriority[priority.wireValue] ?? 0) > 0)
          MapEntry(priority, byPriority[priority.wireValue]!),
    ];

    if (entries.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(child: Text('Sem tarefas ainda')),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: [
                for (final entry in entries)
                  PieChartSectionData(
                    value: entry.value.toDouble(),
                    color: _colorOf(semantic, entry.key),
                    radius: 40,
                    title: '${entry.value}',
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _colorOf(semantic, entry.key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${PriorityBadge.labels[entry.key]}: ${entry.value}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _PeakHourChart extends StatelessWidget {
  const _PeakHourChart({required this.peakHour});

  final PeakHour peakHour;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final histogram = peakHour.histogram;
    final hasData = histogram.any((count) => count > 0);

    if (!hasData) {
      return const SizedBox(
        height: 260,
        child: Center(child: Text('Sem dados suficientes ainda')),
      );
    }

    final maxCount = histogram.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          maxY: maxCount * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                // Intervalo 3 (0h, 3h, 6h...) — com 24 barras, rótulo em
                // toda hora fica ilegível; mesma técnica defensiva de
                // `_MonthlyBarChart`/`_WeeklyActivityChart` pra evitar pedido
                // de rótulo fora dos índices inteiros reais.
                interval: 3,
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final hour = value.round();
                  if (hour < 0 ||
                      hour >= 24 ||
                      hour % 3 != 0 ||
                      hour != value) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${hour}h',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var hour = 0; hour < 24; hour++)
              BarChartGroupData(
                x: hour,
                barRods: [
                  BarChartRodData(
                    toY: histogram[hour].toDouble(),
                    color: hour == peakHour.peakHour
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(alpha: 0.35),
                    width: 8,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ProjectBreakdownChart extends StatelessWidget {
  const _ProjectBreakdownChart({required this.entries});

  final List<ProjectBreakdownEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    if (entries.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('Nenhum projeto com tarefas ainda')),
      );
    }

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    entry.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.progress / 100,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: entry.isOverdue
                          ? semantic.priorityHigh
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: Text(
                    '${entry.progress}% · ${entry.taskCount} tarefa${entry.taskCount == 1 ? '' : 's'}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WeeklyActivityChart extends StatelessWidget {
  const _WeeklyActivityChart({required this.data});

  final List<WeeklyStatusPoint> data;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    // Mesmos índices de cor que `StatusBadge`/`StatusPieChart` usam pros
    // status equivalentes do seed (`Todo`=1, `In Progress`=2,
    // `In Review`=3, `Done`=4) — consistência de cor com o resto do app.
    final todoColor = semantic.statusColorAt(1);
    final inProgressColor = semantic.statusColorAt(2);
    final inReviewColor = semantic.statusColorAt(3);
    final doneColor = semantic.statusColorAt(4);

    final maxValue = data
        .expand((d) => [d.todo, d.inProgress, d.inReview, d.done])
        .fold<int>(0, (max, v) => v > max ? v : max);

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: (maxValue == 0 ? 1 : maxValue) * 1.2,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    // Mesmo motivo do `_MonthlyBarChart` — sem `interval:1`
                    // o eixo pedia rótulo pra dezenas de valores fora dos 7
                    // índices reais (dias da semana repetidos/quebrados).
                    interval: 1,
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= data.length || index != value)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          data[index].dayLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                _line([
                  for (var i = 0; i < data.length; i++)
                    FlSpot(i.toDouble(), data[i].todo.toDouble()),
                ], todoColor),
                _line([
                  for (var i = 0; i < data.length; i++)
                    FlSpot(i.toDouble(), data[i].inProgress.toDouble()),
                ], inProgressColor),
                _line([
                  for (var i = 0; i < data.length; i++)
                    FlSpot(i.toDouble(), data[i].inReview.toDouble()),
                ], inReviewColor),
                _line([
                  for (var i = 0; i < data.length; i++)
                    FlSpot(i.toDouble(), data[i].done.toDouble()),
                ], doneColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 8,
          children: [
            _LegendDot(color: todoColor, label: 'A Fazer'),
            _LegendDot(color: inProgressColor, label: 'Em Andamento'),
            _LegendDot(color: inReviewColor, label: 'Em Revisão'),
            _LegendDot(color: doneColor, label: 'Concluído'),
          ],
        ),
      ],
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: true),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final insights = buildInsights(
      stats,
      positiveColor: semantic.priorityLow,
      warningColor: semantic.priorityHigh,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights & Recomendações',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 700 ? 2 : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 5,
                children: [
                  for (final insight in insights) _InsightCard(data: insight),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.data});

  final InsightCardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.08),
        border: Border.all(color: data.color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: data.color,
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: data.color,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
