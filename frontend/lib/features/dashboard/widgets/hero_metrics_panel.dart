import 'package:flutter/material.dart';

import '../../../core/models/task.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/semantic_colors.dart';
import '../utils/dashboard_derivations.dart';

/// Substitui `_MetricsRow` (4 `MetricCard` idênticos num grid) - painel com
/// "Tarefas Atrasadas" em destaque (número simples, tocável - leva pra
/// Tarefas já filtrado em atrasadas) e as outras 3 métricas como lista
/// compacta ao lado, sem moldura repetida.
class HeroMetricsPanel extends StatelessWidget {
  const HeroMetricsPanel({super.key, required this.tasks, required this.onTapOverdue});

  final List<Task> tasks;
  final VoidCallback onTapOverdue;

  @override
  Widget build(BuildContext context) {
    final overdue = countOverdue(tasks);
    final secondary = [
      _SecondaryMetric(
        label: 'Vencimento Hoje',
        value: countDueToday(tasks),
        icon: Icons.schedule_outlined,
      ),
      _SecondaryMetric(
        label: 'Concluído Hoje',
        value: countCompletedToday(tasks),
        icon: Icons.check_circle_outline,
      ),
      _SecondaryMetric(
        label: 'Em Andamento',
        value: countInProgress(tasks),
        icon: Icons.track_changes_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 480;

        final hero = _HeroPanel(overdue: overdue, compact: compact, onTap: onTapOverdue);
        final list = _SecondaryMetricsList(items: secondary, compact: compact);

        if (width >= 900) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: hero),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: list),
              ],
            ),
          );
        }
        return Column(
          children: [hero, const SizedBox(height: 16), list],
        );
      },
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.overdue, required this.compact, required this.onTap});

  final int overdue;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final alert = overdue > 0;

    final background = alert ? semantic.priorityHighContainer : colorScheme.surfaceContainerHighest;
    final foreground = alert ? semantic.priorityHigh : colorScheme.onSurfaceVariant;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadii.hero),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.hero),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tarefas Atrasadas',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: foreground),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$overdue',
                style: AppTypography.monoNumber(
                  fontSize: compact ? 44 : 68,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryMetric {
  const _SecondaryMetric({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;
}

class _SecondaryMetricsList extends StatelessWidget {
  const _SecondaryMetricsList({required this.items, required this.compact});

  final List<_SecondaryMetric> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colorScheme.outlineVariant),
            _SecondaryMetricRow(metric: items[i], compact: compact),
          ],
        ],
      ),
    );
  }
}

class _SecondaryMetricRow extends StatelessWidget {
  const _SecondaryMetricRow({required this.metric, required this.compact});

  final _SecondaryMetric metric;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
      child: Row(
        children: [
          Icon(metric.icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              metric.label,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            '${metric.value}',
            style: AppTypography.monoNumber(fontSize: compact ? 18 : 22, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
