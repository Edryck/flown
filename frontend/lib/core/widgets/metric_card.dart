import 'package:flutter/material.dart';

import '../theme/semantic_colors.dart';

/// Indicador de tendência do MetricCard (seta + texto colorido). Equivalente
/// ao campo opcional `trend` de MetricCardProps no protótipo.
class MetricTrend {
  const MetricTrend({required this.value, required this.positive});

  final String value;

  /// Controla cor (verde/vermelho) e direção da seta — sem relação com
  /// prioridade de task, só reaproveita as mesmas 2 cores por convenção
  /// (igual ao protótipo, ver docs/prototype/components/metric-card.md).
  final bool positive;
}

/// Card de métrica única (valor grande + título + ícone grande sangrando
/// pela borda + trend opcional). Redesenhado a partir de uma referência
/// visual (`image.png`, raiz do repo) pedida pelo usuário — não é mais fiel
/// ao MetricCard.tsx do protótipo (docs/prototype/components/metric-card.md,
/// que usava um ícone pequeno num chip colorido): ícone grande, meio cortado
/// pelo canto do card, e o card mais baixo/largo. Mantém a mesma animação de
/// entrada (fade + slide-up) e o hover com sombra do design anterior.
class MetricCard extends StatefulWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.subtitle,
    this.trend,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  final MetricTrend? trend;

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final curved = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    final accentColor = widget.iconColor ?? colorScheme.primary;

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                // Ícone grande sangrando pra fora do card, cortado pela borda
                // (`clipBehavior` acima) — mesmo tratamento de `image.png`.
                Positioned(
                  right: -24,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Icon(widget.icon, size: 92, color: accentColor.withValues(alpha: 0.9)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.value,
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.title,
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (widget.trend != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${widget.trend!.positive ? '↑' : '↓'} ${widget.trend!.value}',
                          style: TextStyle(
                            color: widget.trend!.positive ? semantic.priorityLow : semantic.priorityHigh,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}