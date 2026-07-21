/// Erro vindo da API, no mesmo formato que o `error-handler.middleware.ts`
/// do backend sempre devolve: `{ message: string }` + status HTTP.
class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isValidationError => statusCode == 400;

  @override
  String toString() => message;
}
