import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_mode_provider.g.dart';

/// Tema claro/escuro do app — equivalente ao `ThemeContext.tsx` do
/// protótipo (usado pelo toggle do `TopNavBar`,
/// docs/prototype/components/top-nav-bar.md). Começa em `system` (mesma
/// lógica do protótipo: detecta a preferência do SO no primeiro load via
/// `prefers-color-scheme`), mas a partir do primeiro toggle vira sempre
/// explícito (light/dark) e nunca mais volta pra `system` — igual ao
/// comportamento do `ThemeContext` original, que só conhece 2 estados.
///
/// Sem persistência ainda (o protótipo usa `localStorage`) — fica só em
/// memória por enquanto; adicionar `shared_preferences` é uma decisão de
/// dependência nova, deixada pra quando isso vier a incomodar de verdade.
@riverpod
class AppThemeMode extends _$AppThemeMode {
  @override
  ThemeMode build() => ThemeMode.system;

  void toggle(Brightness currentBrightness) {
    state = currentBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
  }
}
