import 'package:flutter/material.dart';

import '../theme/semantic_colors.dart';
import 'badge_size.dart';

/// Pílula colorida com o status de uma task. Tradução fiel do
/// StatusBadge.tsx (docs/prototype/components/status-badge.md) na forma
/// visual (pílula, borda, 2 tamanhos), mas com API adaptada: no backend real
/// `status` é String livre validada contra `ProjectType.availableStatus`
/// (não um enum fixo de 5 valores como o mock do protótipo) — então a cor
/// vem da posição do status dentro do `availableStatus` do projeto, não do
/// nome do status (ver `AppSemanticColors.statusColorAt` em
/// theme/semantic_colors.dart), e o label é o texto que o backend devolve,
/// sem tradução fixa pro português como o protótipo faz.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.colorIndex,
    this.size = BadgeSize.sm,
  });

  /// Texto do status como vem do backend (ex: "Done", "Blocked").
  final String label;

  /// Posição do status dentro de `ProjectType.availableStatus` — decide qual
  /// cor da paleta cíclica usar (ver docs/prototype/components/status-badge.md,
  /// seção "Observações pra tradução Flutter").
  final int colorIndex;
  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final fg = semantic.statusColorAt(colorIndex);
    final bg = semantic.statusContainerColorAt(colorIndex);
    final isSmall = size == BadgeSize.sm;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: isSmall ? 2 : 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
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
