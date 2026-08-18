import 'package:flutter/material.dart';

import '../models/task_priority.dart';
import '../theme/semantic_colors.dart';
import 'priority_badge.dart';

/// Faixa colorida cheia (não uma pílula) pra prioridade - usada onde a
/// prioridade merece ser o primeiro sinal visual do card/diálogo (Kanban,
/// `TaskViewDialog`), diferente do `PriorityBadge` (pílula pequena, usada
/// onde a prioridade é só mais um dado entre outros, como na Tabela).
/// Cor sempre vívida (`semantic.priorityX`, não o container pastel) e texto
/// contrastante calculado pelo brilho da cor - necessário porque as cores de
/// prioridade são escuras no tema claro mas claras no escuro (mesma lógica
/// já usada nos cabeçalhos de coluna do Kanban).
class PriorityBanner extends StatelessWidget {
  const PriorityBanner({super.key, required this.priority, this.borderRadius});

  final TaskPriority priority;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final color = switch (priority) {
      TaskPriority.high => semantic.priorityHigh,
      TaskPriority.medium => semantic.priorityMedium,
      TaskPriority.low => semantic.priorityLow,
    };
    final foreground = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: borderRadius),
      child: Text(
        // Só o nível ("ALTA"/"MÉDIA"/"BAIXA"), sem prefixo "Prioridade" - a
        // própria faixa colorida já deixa claro do que se trata, repetir em
        // texto só ocupava espaço à toa num card pequeno.
        PriorityBadge.labels[priority]!.toUpperCase(),
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
