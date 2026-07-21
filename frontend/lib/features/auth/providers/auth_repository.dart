import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/auth_response.dart';
import '../../../core/models/user.dart';
import '../../../core/services/token_storage.dart';

part 'auth_repository.g.dart';

/// Fala com `/auth/*` e `GET /users/me`. Sempre que um login/register da
/// certo, os tokens ja saem salvos no `TokenStorage` — quem chama esse
/// repository nao precisa lidar com isso na mao.
class AuthRepository {
  AuthRepository(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'name': name, 'email': email, 'password': password},
      );
      final auth = AuthResponse.fromJson(response.data!);
      await _tokenStorage.saveTokens(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
      );
      return auth.user;
    });
  }

  Future<User> login({required String email, required String password}) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final auth = AuthResponse.fromJson(response.data!);
      await _tokenStorage.saveTokens(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
      );
      return auth.user;
    });
  }

  Future<void> logout() {
    return guardApiCall(() async {
      final refreshToken = await _tokenStorage.readRefreshToken();
      if (refreshToken != null) {
        try {
          await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
        } on DioException {
          // Mesmo se o servidor recusar, o token local e apagado — o
          // usuario nao pode ficar preso logado por um erro de rede aqui.
        }
      }
      await _tokenStorage.clear();
    });
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) {
    return guardApiCall(() {
      return _dio.post(
        '/auth/change-password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    });
  }

  /// Chamado uma vez no boot do app: se ja existir um access token salvo de
  /// uma sessao anterior, confirma que ele ainda vale buscando o usuario
  /// (`GET /users/me`) — se o token estiver invalido/expirado (401), o
  /// `_AuthInterceptor` ja tenta o refresh sozinho antes disso chegar aqui
  /// como erro; se falhar mesmo assim, a sessao e considerada encerrada.
  Future<User?> restoreSession() async {
    final token = await _tokenStorage.readAccessToken();
    if (token == null) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>('/users/me');
      return User.fromJson(response.data!);
    } on DioException {
      // Token invalido/expirado — o _AuthInterceptor ja tentou o refresh
      // sozinho antes disso chegar aqui como erro. Se ainda assim falhou,
      // a sessao anterior nao vale mais.
      await _tokenStorage.clear();
      return null;
    }
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  final dio = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return AuthRepository(dio, tokenStorage);
}
