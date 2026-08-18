import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/auth_response.dart';
import '../../../core/models/user.dart';
import '../../../core/services/token_storage.dart';
import 'google_login_launcher.dart';
import 'google_web_redirect.dart';

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

  /// Login com Google — Desktop abre o navegador do sistema e escuta um
  /// servidor HTTP local (`google_login_launcher.dart`); Web navega a
  /// própria aba pro backend e só volta quando ele redireciona de volta
  /// pra cá com o handoff na URL (ver `GoogleCallbackScreen`, que chama
  /// `completeGoogleWebLogin` do lado de cá).
  Future<User> loginWithGoogle() {
    if (kIsWeb) {
      return guardApiCall(() async {
        final webRedirect = '${currentWebOrigin()}/#/auth/google/callback';
        final authorizeUrl = Uri.parse(
          '$apiBaseUrl/auth/google/authorize',
        ).replace(queryParameters: {'webRedirect': webRedirect});

        redirectToWebUrl(authorizeUrl.toString());
        // A navegação acima descarta essa página — esse Future nunca
        // precisa resolver de verdade.
        return Completer<User>().future;
      });
    }

    return guardApiCall(() async {
      final handoff = await runGoogleDesktopLoginFlow(apiBaseUrl);
      return _exchangeGoogleHandoff(handoff);
    });
  }

  /// Chamado pela `GoogleCallbackScreen` (Web) depois que o backend devolve
  /// o controle pra própria origem do app com `?handoff=...` na URL.
  Future<User> completeGoogleWebLogin(String handoff) {
    return guardApiCall(() => _exchangeGoogleHandoff(handoff));
  }

  Future<User> _exchangeGoogleHandoff(String handoff) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/google/exchange',
      data: {'handoff': handoff},
    );
    final data = response.data!;
    await _tokenStorage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );

    final userResponse = await _dio.get<Map<String, dynamic>>('/users/me');
    return User.fromJson(userResponse.data!);
  }

  /// Só pra decidir se o botão de bypass de dev aparece na tela de login —
  /// nunca deve travar a tela se o backend estiver fora do ar ou a rota
  /// falhar por qualquer motivo, então erros aqui viram `false` (esconde o
  /// botão) em vez de propagar como nas outras chamadas deste repository.
  Future<bool> checkSkipAuthEnabled() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/dev-mode');
      return response.data?['skipAuth'] as bool? ?? false;
    } on DioException {
      return false;
    }
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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return guardApiCall(() {
      return _dio.post(
        '/auth/change-password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    });
  }

  Future<User> updateProfile({
    String? name,
    String? email,
    int? taskArchiveDays,
    int? projectArchiveDays,
  }) {
    return guardApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/users/me',
        data: {
          'name': ?name,
          'email': ?email,
          'taskArchiveDays': ?taskArchiveDays,
          'projectArchiveDays': ?projectArchiveDays,
        },
      );
      return User.fromJson(response.data!);
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
