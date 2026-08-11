import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_presets.dart';

part 'theme_preset_provider.g.dart';

const _kThemePreset = 'theme.preset';

/// Preset de paleta selecionado nas Configurações > Aparência > Paleta.
/// Persistido via `shared_preferences` (mesmo padrão de
/// `settings_preferences.dart`) pra sobreviver a reinícios do app - ao
/// contrário do toggle claro/escuro (`theme_mode_provider.dart`), que ainda é
/// só em memória.
@riverpod
class AppThemePreset extends _$AppThemePreset {
  @override
  FutureOr<ThemePreset> build() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kThemePreset);
    return id == null ? ThemePreset.flown : ThemePreset.fromId(id);
  }

  Future<void> select(ThemePreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemePreset, preset.id);
    state = AsyncData(preset);
  }
}
