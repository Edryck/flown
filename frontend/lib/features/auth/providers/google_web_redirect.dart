// Ponto de entrada da navegacao de pagina inteira usada no fluxo Web do
// login com Google — Desktop nunca importa isso (usa o servidor HTTP local
// de `google_login_launcher.dart`). Mesma tecnica de import condicional:
// o Dart escolhe o arquivo certo em tempo de compilacao via
// `dart.library.html`, nunca em runtime.
export 'google_web_redirect_stub.dart'
    if (dart.library.html) 'google_web_redirect_web.dart';
