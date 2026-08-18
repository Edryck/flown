import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'app_typography.dart';
import 'semantic_colors.dart';

/// Temas de paleta fixa, escolhidos nas Configurações > Aparência > Paleta.
/// Diferente do Padrão Flown (`AppTheme.light`/`.dark`, que segue o toggle
/// claro/escuro do sistema), cada preset aqui é uma identidade visual única
/// e fechada - "Dark Forest" é sempre escuro, "Mystical Garden" é sempre
/// claro etc. - por isso `ThemeData` único por preset, sem variante de
/// brilho. `isLight`/`isDark` agrupam os cards de seleção nas Configurações
/// em duas seções (Claro/Escuro); Padrão Flown fica de fora dos dois grupos.
enum ThemePreset {
  flown('flown', 'Padrão Flown'),
  mysticalGarden('mystical_garden', 'Mystical Garden'),
  greenSerenity('green_serenity', 'Green Serenity'),
  darkForest('dark_forest', 'Dark Forest'),
  midnightOcean('midnight_ocean', 'Midnight Ocean');

  const ThemePreset(this.id, this.label);

  final String id;
  final String label;

  static ThemePreset fromId(String id) =>
      ThemePreset.values.firstWhere((p) => p.id == id, orElse: () => flown);

  bool get isLight => this == mysticalGarden || this == greenSerenity;

  bool get isDark => this == darkForest || this == midnightOcean;

  /// `null` pro Padrão Flown - esse continua dependendo de
  /// `AppThemeMode`/brilho do sistema, ao contrário dos demais.
  ThemeData? get fixedThemeData => switch (this) {
    ThemePreset.flown => null,
    ThemePreset.mysticalGarden => AppThemePresets.mysticalGarden,
    ThemePreset.greenSerenity => AppThemePresets.greenSerenity,
    ThemePreset.darkForest => AppThemePresets.darkForest,
    ThemePreset.midnightOcean => AppThemePresets.midnightOcean,
  };

  /// Amostra de 3 cores pro card de seleção nas Configurações (primária,
  /// secundária, fundo) - pro Padrão Flown mostra os tons do tema claro.
  List<Color> get swatch => switch (this) {
    ThemePreset.flown => const [
      Color(0xFF3D4E5C),
      Color(0xFF5A8A86),
      Color(0xFFF5F7FA),
    ],
    ThemePreset.mysticalGarden => const [
      Color(0xFF750D37),
      Color(0xFFB3DEC1),
      Color(0xFFF7F9F7),
    ],
    ThemePreset.greenSerenity => const [
      Color(0xFF709775),
      Color(0xFF8FB996),
      Color(0xFFA1CCA5),
    ],
    ThemePreset.darkForest => const [
      Color(0xFF12562A),
      Color(0xFF720714),
      Color(0xFF0B0F0C),
    ],
    ThemePreset.midnightOcean => const [
      Color(0xFF4FA8C9),
      Color(0xFF334753),
      Color(0xFF001420),
    ],
  };
}

/// `ThemeData` de cada preset de paleta fixa. Mesma técnica de
/// `AppTheme` (seed + `copyWith` com os tons exatos da paleta) - só que aqui
/// uma paleta de 5 cores dadas pelo usuário vira os papéis de
/// primary/secondary/background/foreground, com tons de apoio (card, border,
/// muted, destructive, ring) derivados pra fechar um `ColorScheme` inteiro.
class AppThemePresets {
  AppThemePresets._();

  static ThemeData _build({
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color onSecondary,
    required Color background,
    required Color card,
    required Color foreground,
    required Color mutedForeground,
    required Color border,
    required Color destructive,
    required Color onDestructive,
    required Color ring,
    required Brightness brightness,
    required AppSemanticColors semanticColors,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      surface: background,
      onSurface: foreground,
      onSurfaceVariant: mutedForeground,
      error: destructive,
      onError: onDestructive,
      outline: border,
      outlineVariant: border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme(brightness),
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sharp),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sharp),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sharp),
          borderSide: BorderSide(color: ring, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sharp),
          ),
        ),
      ),
      extensions: [semanticColors],
    );
  }

  /// Claro, elegante - burgundy sobre fundo quase-branco com toques de menta.
  static ThemeData get mysticalGarden => _build(
    primary: const Color(0xFF750D37),
    onPrimary: Colors.white,
    secondary: const Color(0xFFB3DEC1),
    onSecondary: const Color(0xFF210124),
    background: const Color(0xFFF7F9F7),
    card: Colors.white,
    foreground: const Color(0xFF210124),
    mutedForeground: const Color(0xFF7C6B80),
    border: const Color(0xFFE3D9E6),
    destructive: const Color(0xFFC0435F),
    onDestructive: Colors.white,
    ring: const Color(0xFF8FC7A8),
    brightness: Brightness.light,
    semanticColors: AppSemanticColors.light,
  );

  /// Claro, natural - verde-sálvia em várias intensidades, sem branco puro.
  static ThemeData get greenSerenity => _build(
    primary: const Color(0xFF709775),
    onPrimary: Colors.white,
    secondary: const Color(0xFF8FB996),
    onSecondary: const Color(0xFF111D13),
    background: const Color(0xFFA1CCA5),
    card: const Color(0xFFCFE7D1),
    foreground: const Color(0xFF111D13),
    mutedForeground: const Color(0xFF415D43),
    border: const Color(0xFFBFD3C2),
    destructive: const Color(0xFFB5533F),
    onDestructive: Colors.white,
    ring: const Color(0xFF709775),
    brightness: Brightness.light,
    semanticColors: AppSemanticColors.light,
  );

  /// Escuro, denso - verde-floresta e vermelho-sangue sobre quase-preto.
  static ThemeData get darkForest => _build(
    primary: const Color(0xFF3E8F5B),
    onPrimary: const Color(0xFF0B0F0C),
    secondary: const Color(0xFF720714),
    onSecondary: Colors.white,
    background: const Color(0xFF0B0F0C),
    card: const Color(0xFF14211A),
    foreground: const Color(0xFFE7ECE8),
    mutedForeground: const Color(0xFF8FA091),
    border: const Color(0xFF23302A),
    destructive: const Color(0xFFC1493A),
    onDestructive: Colors.white,
    ring: const Color(0xFF3E8F5B),
    brightness: Brightness.dark,
    semanticColors: AppSemanticColors.dark,
  );

  /// Escuro, sofisticado - degradê azul-marinho profundo com acento ciano.
  static ThemeData get midnightOcean => _build(
    primary: const Color(0xFF4FA8C9),
    onPrimary: const Color(0xFF000D15),
    secondary: const Color(0xFF6FBFD9),
    onSecondary: const Color(0xFF000D15),
    background: const Color(0xFF000D15),
    card: const Color(0xFF001A2A),
    foreground: const Color(0xFFE4E9EC),
    mutedForeground: const Color(0xFF65747B),
    border: const Color(0xFF334753),
    destructive: const Color(0xFFE2665A),
    onDestructive: Colors.white,
    ring: const Color(0xFF4FA8C9),
    brightness: Brightness.dark,
    semanticColors: AppSemanticColors.dark,
  );
}
