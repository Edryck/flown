import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografia comum às 6 identidades visuais do app (Padrão Flown +
/// presets fixos de `theme_presets.dart`) - Geist substitui a fonte default
/// do Material, que é a mesma em qualquer app não desenhado de propósito.
/// Um só `TextTheme` aqui, aplicado em todos os `ThemeData` do app.
class AppTypography {
  AppTypography._();

  /// Corpo de texto/títulos em geral.
  static TextTheme textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    return GoogleFonts.geistTextTheme(base);
  }

  /// Só pros números grandes de métrica (`HeroMetricsPanel`) - Geist Mono dá
  /// a leitura de "dado preciso" que a Geist Sans (título/corpo) não tem.
  static TextStyle monoNumber({required double fontSize, Color? color}) {
    return GoogleFonts.geistMono(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1,
    );
  }
}
