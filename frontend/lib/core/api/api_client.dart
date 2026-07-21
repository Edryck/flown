import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/token_storage.dart';
import 'api_exception.dart';

/// URL base da API. Pra trocar em build/debug: `--dart-define=API_BASE_URL=...`
/// (default bate com `PORT=3333` do `.env` do backend em dev local).
const _defaultBaseUrl = 'http://localhost:3333';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: _defaultBaseUrl);

/// Converte `DioException` pro formato unico que o resto do app conhece
/// (`ApiException`), lendo `{ message }` do corpo quando o backend respondeu
/// (ver `error-handler.middleware.ts`), ou uma mensagem generica se a
/// requisicao nem chegou a ter resposta (rede fora, timeout).
ApiException _toApiException(DioException error) {
  final response = error.response;
  if (response == null) {
    return const ApiException(statusCode: 0, message: 'Falha de conexao com o servidor');
  }
  final data = response.data;
  final message = (data is Map && data['message'] is String)
      ? data['message'] as String
      : 'Erro inesperado (${response.statusCode})';
  return ApiException(statusCode: response.statusCode ?? 0, message: message);
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._tokenStorage, this._refreshDio);

  final TokenStorage _tokenStorage;
  final Dio _refreshDio;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokenStorage.readAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthEndpoint = err.requestOptions.path.startsWith('/auth/');
    if (err.response?.statusCode != 401 || isAuthEndpoint) {
      handler.reject(err.copyWith(error: _toApiException(err)));
      return;
    }

    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      await _tokenStorage.clear();
      handler.reject(err.copyWith(error: _toApiException(err)));
      return;
    }

    try {
      final refreshResponse = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final newAccessToken = refreshResponse.data['accessToken'] as String;
      await _tokenStorage.saveAccessToken(newAccessToken);

      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      final retryResponse = await _refreshDio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } on DioException {
      // Refresh token tambem invalido/expirado — so resta deslogar.
      await _tokenStorage.clear();
      handler.reject(err.copyWith(error: _toApiException(err)));
    }
  }
}

/// Instancia unica de `Dio`, com o `Authorization` header automatico e o
/// fluxo de refresh-then-retry num 401. Todos os repositories de feature
/// devem usar esse client, nunca criar `Dio()` proprio.
final apiClientProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);

  // Instancia separada, sem os interceptors, usada só pra chamar
  // /auth/refresh e reexecutar a requisicao original — evita recursao
  // infinita se o proprio refresh desse 401.
  final refreshDio = Dio(BaseOptions(baseUrl: apiBaseUrl));

  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  dio.interceptors.add(_AuthInterceptor(tokenStorage, refreshDio));

  return dio;
});
