import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Card de métrica compacto (rótulo + número mono grande + ícone sangrando
/// no canto, fundo tintado na cor do item) — extraído de `_StatCard` em
/// `projects_screen.dart` (era privado daquela tela) pra ser reaproveitado
/// em outras faixas de métricas (Estatísticas). Fundo inteiro tintado
/// (tom sobre tom com o ícone) + ícone grande sangrando é o padrão que
/// sobreviveu a várias iterações ali — ver histórico de `projects_screen.dart`.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.labelFontSize,
    this.valueFontSize = 28,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// `null` usa `theme.textTheme.bodySmall` (tamanho padrão de `_StatCard`).
  final double? labelFontSize;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.15),
          theme.cardTheme.color ?? colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Icon(icon, size: 84, color: color.withValues(alpha: 0.35)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: labelFontSize,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: AppTypography.monoNumber(
                    fontSize: valueFontSize,
                    color: colorScheme.onSurface,
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
