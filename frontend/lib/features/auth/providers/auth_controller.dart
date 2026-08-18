import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/user.dart';
import '../../notes/providers/note_list_controller.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../tasks/providers/task_list_controller.dart';
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
      return ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref
          .read(authRepositoryProvider)
          .register(name: name, email: email, password: password);
    });
  }

  Future<void> loginWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).loginWithGoogle();
    });
  }

  /// Chamado pela `GoogleCallbackScreen` — continuação de [loginWithGoogle]
  /// depois que a Web volta do redirect do backend com o handoff na URL.
  Future<void> completeGoogleWebLogin(String handoff) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(authRepositoryProvider).completeGoogleWebLogin(handoff);
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
    // As list controllers de Tasks/Projects/Notes sao keepAlive (ver
    // task_list_controller.dart) - sem invalidar aqui, os dados do usuario
    // que acabou de sair ficam em memoria e vazam pra tela caso outro
    // usuario faca login na mesma instancia do app, sem reiniciar.
    ref.invalidate(taskListControllerProvider);
    ref.invalidate(projectListControllerProvider);
    ref.invalidate(noteListControllerProvider);
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    int? taskArchiveDays,
    int? projectArchiveDays,
  }) async {
    final updated = await ref.read(authRepositoryProvider).updateProfile(
      name: name,
      email: email,
      taskArchiveDays: taskArchiveDays,
      projectArchiveDays: projectArchiveDays,
    );
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
        taskArchiveDays: 3,
        projectArchiveDays: 30,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }
}

/// Se o botão de bypass de dev deve aparecer na tela de login — reflete o
/// `SKIP_AUTH` real do backend (`GET /auth/dev-mode`), não só o modo debug
/// do Flutter. Sem isso, o botão continuava visível em builds debug mesmo
/// com o backend já exigindo login de verdade, e clicar nele deixava a UI
/// num estado "logado" falso que quebrava (401) na primeira chamada real.
@riverpod
Future<bool> devBypassAvailable(DevBypassAvailableRef ref) {
  return ref.watch(authRepositoryProvider).checkSkipAuthEnabled();
}
