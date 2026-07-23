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

/// Card de métrica única (título + valor grande + ícone + trend opcional).
/// Tradução fiel de MetricCard.tsx
/// (docs/prototype/components/metric-card.md): mesma composição visual e a
/// mesma animação de entrada (fade + slide-up, 0.3s) e o mesmo hover com
/// sombra — mas usando cores do `ColorScheme`/tema em vez de hardcoded,
/// corrigindo o gap de dark mode que o componente original tem
/// (docs/prototype/01-dark-mode-gaps.md).
class MetricCard extends StatefulWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconBackgroundColor,
    this.iconColor,
    this.subtitle,
    this.trend,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? iconBackgroundColor;
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

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.value,
                          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (widget.trend != null) ...[
                          const SizedBox(height: 8),
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
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.iconBackgroundColor ?? colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, size: 24, color: widget.iconColor ?? colorScheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
