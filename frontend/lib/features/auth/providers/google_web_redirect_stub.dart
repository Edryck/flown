// Usado em qualquer target que nao seja Web (Desktop) — nunca deveria ser
// chamado de verdade, ja que `AuthRepository.loginWithGoogle` so usa isso
// quando `kIsWeb` e verdadeiro.
String currentWebOrigin() {
  throw UnsupportedError('Login com Google via redirect só existe na Web.');
}

void redirectToWebUrl(String url) {
  throw UnsupportedError('Login com Google via redirect só existe na Web.');
}
