/// Usado em qualquer target sem `dart:io` (hoje só Web) — o login com
/// Google via navegador do sistema ainda não tem um equivalente pra Web
/// (precisaria de um redirect de página inteira em vez de servidor local).
Future<String> runGoogleDesktopLoginFlow(String baseUrl) {
  throw UnsupportedError(
    'Login com Google ainda só está disponível na versão Desktop.',
  );
}
