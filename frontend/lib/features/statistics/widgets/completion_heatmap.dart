import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../providers/dashboard_stats_repository.dart';

/// Grade estilo "contribution graph" (GitHub) com as conclusões por dia —
/// não existe no protótipo (`Statistics.tsx` não tem nada parecido), é uma
/// visualização nova pedida pra aproveitar `productivity.heatmap`, dado
/// real que o backend já calcula e o protótipo nunca usou.
///
/// Sempre o ano calendário corrente inteiro (1º de janeiro a 31 de
/// dezembro) — não uma janela móvel de N dias terminando hoje. Antes disso,
/// em qualquer mês que não dezembro o último quadradinho (hoje) ficava bem
/// no meio/início da grade, sem nenhum eixo temporal reconhecível; dias
/// antes de janeiro (sobra do alinhamento de semana) e depois de hoje
/// (futuro) ficam em branco.
class CompletionHeatmap extends StatelessWidget {
  const CompletionHeatmap({super.key, required this.entries});

  final List<HeatmapEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final countByDate = <DateTime, int>{
      for (final e in entries) DateTime(e.date.year, e.date.month, e.date.day): e.count,
    };
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yearStart = DateTime(today.year, 1, 1);
    final yearEnd = DateTime(today.year, 12, 31);
    final alignedStart = yearStart.subtract(Duration(days: yearStart.weekday % 7));
    final totalDays = yearEnd.difference(alignedStart).inDays + 1;
    final weeks = (totalDays / 7).ceil();
    final maxCount = entries.isEmpty ? 0 : entries.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    Color colorFor(int count) {
      if (count == 0) return colorScheme.surfaceContainerHighest;
      final intensity = maxCount == 0 ? 1.0 : (count / maxCount).clamp(0.25, 1.0);
      return Color.lerp(colorScheme.primary.withValues(alpha: 0.25), colorScheme.primary, intensity)!;
    }

    final grid = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var w = 0; w < weeks; w++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var d = 0; d < 7; d++)
                  Builder(
                    builder: (context) {
                      final date = alignedStart.add(Duration(days: w * 7 + d));
                      if (date.isBefore(yearStart) || date.isAfter(yearEnd) || date.isAfter(todayDate)) {
                        return const SizedBox(width: 12, height: 12);
                      }
                      final count = countByDate[date] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Tooltip(
                          message: '${DateFormat('dd/MM').format(date)}: $count concluída${count == 1 ? '' : 's'}',
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colorFor(count),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
    );

    // `Center` só funciona fora do `SingleChildScrollView`: dentro dele o
    // eixo de rolagem (horizontal) recebe largura NÃO limitada, e um
    // `Center` com largura ilimitada quebra o layout. Por isso mede a
    // largura da grade primeiro (via `LayoutBuilder`) e só cai pro scroll
    // horizontal se ela realmente não couber — senão fica centralizada,
    // preenchendo a largura do card.
    const columnWidth = 15.0; // 12px de quadrado + 3px de espaço
    final gridWidth = weeks * columnWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (gridWidth <= constraints.maxWidth) {
          return Center(child: grid);
        }
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid);
      },
    );
  }
}