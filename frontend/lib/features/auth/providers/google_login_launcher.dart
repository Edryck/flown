// Ponto de entrada do fluxo de login com Google — a implementação real
// depende da plataforma (Desktop abre um servidor HTTP local temporário
// pra receber a resposta; Web ainda não está implementada, ver
// `google_login_launcher_stub.dart`). O Dart escolhe o arquivo certo em
// tempo de compilação via `dart.library.io` — nunca em runtime — porque
// `dart:io` nem existe no target Web e quebraria o build se fosse
// importado direto num arquivo compartilhado.
export 'google_login_launcher_stub.dart'
    if (dart.library.io) 'google_login_launcher_io.dart';
