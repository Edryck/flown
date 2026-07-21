import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Roda uma chamada via [ApiClient] e converte qualquer `DioException` numa
/// `ApiException` (o `_AuthInterceptor` de `api_client.dart` ja anexa a
/// `ApiException` certa em `DioException.error` — aqui so desembrulha,
/// pra nenhuma camada acima de repository precisar conhecer Dio).
Future<T> guardApiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    final error = e.error;
    if (error is ApiException) throw error;
    rethrow;
  }
}
