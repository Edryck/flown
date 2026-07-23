import 'package:flutter/material.dart';

import '../models/task_priority.dart';
import '../theme/semantic_colors.dart';
import 'badge_size.dart';

/// Pílula colorida com a prioridade de uma task. Tradução fiel de
/// PriorityBadge.tsx (docs/prototype/components/priority-badge.md) — mesmas
/// 3 cores, mesmos labels, mesmos 2 tamanhos, mesma sombra sutil só na
/// prioridade alta — mas usando os tokens de tema (AppSemanticColors) em vez
/// de classes hardcoded, já cobrindo dark mode (gap documentado em
/// docs/prototype/01-dark-mode-gaps.md).
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({
    super.key,
    required this.priority,
    this.size = BadgeSize.sm,
  });

  final TaskPriority priority;
  final BadgeSize size;

  /// Público de propósito: reaproveitado pelo `TaskFormScreen` no Select de
  /// prioridade, evitando duplicar o mapeamento "Alta/Média/Baixa".
  static const labels = {
    TaskPriority.high: 'Alta',
    TaskPriority.medium: 'Média',
    TaskPriority.low: 'Baixa',
  };

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final (Color fg, Color bg) = switch (priority) {
      TaskPriority.high => (semantic.priorityHigh, semantic.priorityHighContainer),
      TaskPriority.medium => (semantic.priorityMedium, semantic.priorityMediumContainer),
      TaskPriority.low => (semantic.priorityLow, semantic.priorityLowContainer),
    };
    final isSmall = size == BadgeSize.sm;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: isSmall ? 2 : 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
        boxShadow: priority == TaskPriority.high
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        labels[priority]!,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w500,
          fontSize: isSmall ? 12 : 14,
          height: 1,
        ),
      ),
    );
  }
}
