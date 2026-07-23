import 'package:flutter/material.dart';

/// Cores que o Material 3 `ColorScheme` não cobre: prioridade de task (fixa,
/// 3 valores) e uma paleta pra status de task (dinamico por ProjectType —
/// nao da pra hardcodar nome de status, entao a cor e escolhida por indice
/// dentro de `ProjectType.availableStatus`, nao pelo nome do status).
///
/// Existe por causa de uma licao aprendida analisando o protototipo React
/// (docs/prototype/01-dark-mode-gaps.md): la, cores "extras" como essas foram
/// definidas so pro modo claro e nunca ganharam versao pro escuro. Aqui as
/// duas variantes (light/dark) sao definidas desde o inicio, lado a lado.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.priorityHigh,
    required this.priorityHighContainer,
    required this.priorityMedium,
    required this.priorityMediumContainer,
    required this.priorityLow,
    required this.priorityLowContainer,
    required this.statusPalette,
    required this.statusPaletteContainer,
  });

  final Color priorityHigh;
  final Color priorityHighContainer;
  final Color priorityMedium;
  final Color priorityMediumContainer;
  final Color priorityLow;
  final Color priorityLowContainer;

  /// Paleta ciclica pra colorir badges de status dinamico. O indice do status
  /// dentro de `ProjectType.availableStatus` decide qual cor usar (nunca o
  /// nome do status — "Done"/"Cancelled"/etc. sao so texto pro backend).
  final List<Color> statusPalette;
  final List<Color> statusPaletteContainer;

  Color statusColorAt(int index) => statusPalette[index % statusPalette.length];

  Color statusContainerColorAt(int index) =>
      statusPaletteContainer[index % statusPaletteContainer.length];

  // Valores identicos aos de --high-priority/--medium-priority/--low-priority
  // (e as variantes -light) do theme.css do prototipo React — fidelidade de
  // verdade com a paleta original, nao uma aproximacao.
  static const light = AppSemanticColors(
    priorityHigh: Color(0xFFD97373),
    priorityHighContainer: Color(0xFFFDE8E8),
    priorityMedium: Color(0xFFE09860),
    priorityMediumContainer: Color(0xFFFEF0E5),
    priorityLow: Color(0xFF6BB88F),
    priorityLowContainer: Color(0xFFE6F7ED),
    statusPalette: [
      Color(0xFF5A6978),
      Color(0xFF3D6FA6),
      Color(0xFFB2560D),
      Color(0xFF7A5AA6),
      Color(0xFF2E7D51),
      Color(0xFF9E1F63),
      Color(0xFF00707A),
      Color(0xFF6B5B00),
    ],
    statusPaletteContainer: [
      Color(0xFFE8ECF0),
      Color(0xFFE8F1F8),
      Color(0xFFFEF0E5),
      Color(0xFFEBE6F3),
      Color(0xFFE6F7ED),
      Color(0xFFFBE5F0),
      Color(0xFFE0F5F6),
      Color(0xFFF5F0DC),
    ],
  );

  static const dark = AppSemanticColors(
    priorityHigh: Color(0xFFFFB4AB),
    priorityHighContainer: Color(0xFF5C1A16),
    priorityMedium: Color(0xFFFFB77C),
    priorityMediumContainer: Color(0xFF5C3300),
    priorityLow: Color(0xFF8FDBA8),
    priorityLowContainer: Color(0xFF0E4327),
    statusPalette: [
      Color(0xFFB8C4D1),
      Color(0xFF9CC5F0),
      Color(0xFFFFB77C),
      Color(0xFFCBB6F0),
      Color(0xFF8FDBA8),
      Color(0xFFF0A8CE),
      Color(0xFF7ED9E0),
      Color(0xFFE0D08A),
    ],
    statusPaletteContainer: [
      Color(0xFF3A4552),
      Color(0xFF1E3A5C),
      Color(0xFF5C3300),
      Color(0xFF3E2E5C),
      Color(0xFF0E4327),
      Color(0xFF5C1A3E),
      Color(0xFF0A3E42),
      Color(0xFF3E3600),
    ],
  );

  @override
  AppSemanticColors copyWith({
    Color? priorityHigh,
    Color? priorityHighContainer,
    Color? priorityMedium,
    Color? priorityMediumContainer,
    Color? priorityLow,
    Color? priorityLowContainer,
    List<Color>? statusPalette,
    List<Color>? statusPaletteContainer,
  }) {
    return AppSemanticColors(
      priorityHigh: priorityHigh ?? this.priorityHigh,
      priorityHighContainer: priorityHighContainer ?? this.priorityHighContainer,
      priorityMedium: priorityMedium ?? this.priorityMedium,
      priorityMediumContainer: priorityMediumContainer ?? this.priorityMediumContainer,
      priorityLow: priorityLow ?? this.priorityLow,
      priorityLowContainer: priorityLowContainer ?? this.priorityLowContainer,
      statusPalette: statusPalette ?? this.statusPalette,
      statusPaletteContainer: statusPaletteContainer ?? this.statusPaletteContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      priorityHigh: Color.lerp(priorityHigh, other.priorityHigh, t)!,
      priorityHighContainer: Color.lerp(priorityHighContainer, other.priorityHighContainer, t)!,
      priorityMedium: Color.lerp(priorityMedium, other.priorityMedium, t)!,
      priorityMediumContainer:
          Color.lerp(priorityMediumContainer, other.priorityMediumContainer, t)!,
      priorityLow: Color.lerp(priorityLow, other.priorityLow, t)!,
      priorityLowContainer: Color.lerp(priorityLowContainer, other.priorityLowContainer, t)!,
      statusPalette: List.generate(
        statusPalette.length,
        (i) => Color.lerp(statusPalette[i], other.statusPalette[i], t)!,
      ),
      statusPaletteContainer: List.generate(
        statusPaletteContainer.length,
        (i) => Color.lerp(statusPaletteContainer[i], other.statusPaletteContainer[i], t)!,
      ),
    );
  }
}

extension AppSemanticColorsContext on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
