import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/user.dart';
import 'auth_repository.dart';

part 'auth_controller.g.dart';

/// Estado de sessao do app inteiro. `null` (dado) = deslogado; `User` (dado)
/// = logado; erro = ultima tentativa de login/register falhou.
///
/// `build()` roda uma vez no boot do app e tenta restaurar uma sessao
/// anterior (token salvo no `TokenStorage`) — enquanto isso pendura, o
/// estado fica em loading e o router (`app_router.dart`) mostra a splash.
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<User?> build() {
    return ref.watch(authRepositoryProvider).restoreSession();
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).login(email: email, password: password);
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).register(name: name, email: email, password: password);
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  Future<void> updateProfile({String? name, String? email}) async {
    final updated = await ref.read(authRepositoryProvider).updateProfile(name: name, email: email);
    state = AsyncData(updated);
  }

  /// Atalho SÓ de desenvolvimento: entra como o usuário fixo que o backend
  /// injeta quando `SKIP_AUTH=true` (`auth.middleware.ts`), sem chamar
  /// `/auth/login` nem guardar token nenhum — o interceptor simplesmente não
  /// manda `Authorization`, e o backend nem confere isso com SKIP_AUTH ligado.
  /// Só deve aparecer na UI em debug (ver login_screen.dart); o método em si
  /// não faz mal nenhum se chamado fora disso, só fica sem uso.
  Future<void> devBypass() async {
    state = AsyncData(
      User(
        id: 'dev-user',
        name: 'Dev User',
        email: 'dev@flown.local',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }
}
