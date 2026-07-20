import 'package:flutter/material.dart';

import 'semantic_colors.dart';

/// `ThemeData` light/dark do app. Base de cor via `ColorScheme.fromSeed`
/// (Material 3), estendida com [AppSemanticColors] pras cores que o Material
/// nao cobre (prioridade, status dinamico).
class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF3D4E5C);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
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
      extensions: const [AppSemanticColors.dark],
    );
  }
}
