import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'nav_layout_provider.g.dart';

const _kNavLayout = 'nav.layout';

/// Layout de navegação escolhido em Configurações > Aparência - `TopNavBar`
/// (barra horizontal fixa) foi o layout original e continua existindo, não
/// foi removido; `AppSidebar` é o padrão novo (também cobre navegação em
/// tela de celular, que o `TopNavBar` nunca teve). Persistido via
/// `shared_preferences`, mesmo padrão de `settings_preferences.dart`.
enum NavLayout {
  sidebar('sidebar'),
  topBar('top_bar');

  const NavLayout(this.id);

  final String id;

  static NavLayout fromId(String id) =>
      NavLayout.values.firstWhere((l) => l.id == id, orElse: () => sidebar);
}

@riverpod
class AppNavLayout extends _$AppNavLayout {
  @override
  FutureOr<NavLayout> build() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kNavLayout);
    return id == null ? NavLayout.sidebar : NavLayout.fromId(id);
  }

  Future<void> select(NavLayout layout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNavLayout, layout.id);
    state = AsyncData(layout);
  }
}
