import 'package:flutter/material.dart';

import 'semantic_colors.dart';

/// `ThemeData` light/dark do app.
///
/// O tema claro usa `ColorScheme.fromSeed` só como base (preenche os tons
/// que o Material 3 precisa mas o protótipo não define), e sobrescreve com
/// `copyWith` as cores que o protótipo React define explicitamente em
/// `theme.css` (`:root`) — sem isso, o Material inventa uma paleta azulada
/// genérica que não bate com a identidade visual real do app (cinza-azulado
/// + verde-sálvia, fundo levemente acinzentado, cards brancos com borda).
class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF3D4E5C);

  // Valores identicos ao :root do theme.css do prototipo.
  static const _lightPrimary = Color(0xFF3D4E5C);
  static const _lightSecondary = Color(0xFF5A8A86);
  static const _lightBackground = Color(0xFFF5F7FA);
  static const _lightForeground = Color(0xFF1A202C);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightBorder = Color(0xFFDDE4EC);
  static const _lightMutedForeground = Color(0xFF6B7B8F);
  static const _lightDestructive = Color(0xFFD97373);
  static const _lightRing = Color(0xFF7BA3C7);

  static const _radius = 10.0;

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: _lightPrimary,
      onPrimary: Colors.white,
      secondary: _lightSecondary,
      onSecondary: Colors.white,
      surface: _lightBackground,
      onSurface: _lightForeground,
      onSurfaceVariant: _lightMutedForeground,
      error: _lightDestructive,
      onError: Colors.white,
      outline: _lightBorder,
      outlineVariant: _lightBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardThemeData(
        color: _lightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: _lightRing, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        ),
      ),
      extensions: const [AppSemanticColors.light],
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        ),
      ),
      extensions: const [AppSemanticColors.dark],
    );
  }
}
