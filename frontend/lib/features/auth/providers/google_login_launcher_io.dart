import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Fluxo de login com Google pra Desktop: sobe um servidor HTTP local
/// temporário numa porta aleatória, abre o navegador do sistema apontando
/// pro backend (que conversa com o Google e devolve o controle pra cá no
/// final), captura a primeira requisição que chegar nesse servidor e
/// extrai o "handoff" — o código de uso único que o app troca por
/// accessToken/refreshToken de verdade em `/auth/google/exchange`.
Future<String> runGoogleDesktopLoginFlow(String baseUrl) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

  try {
    final authorizeUrl = Uri.parse(
      '$baseUrl/auth/google/authorize',
    ).replace(queryParameters: {'redirectPort': '${server.port}'});

    final launched = await launchUrl(
      authorizeUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw StateError('Não foi possível abrir o navegador do sistema.');
    }

    final request = await server.first.timeout(
      const Duration(minutes: 5),
      onTimeout: () =>
          throw TimeoutException('Login com Google expirou. Tente de novo.'),
    );

    final params = request.uri.queryParameters;
    final error = params['error'];
    final handoff = params['handoff'];

    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write(_responsePage(success: error == null && handoff != null));
    await request.response.close();

    if (error != null) {
      throw StateError('Login com Google cancelado ou recusado ($error).');
    }
    if (handoff == null) {
      throw StateError('Resposta inesperada do login com Google.');
    }
    return handoff;
  } finally {
    await server.close(force: true);
  }
}

// Pagina estatica (sem dependencia externa nenhuma - roda offline, direto
// do servidor local) mostrada na aba do navegador depois do redirect final
// do Google. Cores/gradiente batem com `login_screen.dart` de proposito,
// pra nao parecer uma pagina de outro app no meio do fluxo de login.
String _responsePage({required bool success}) {
  final accentColor = success ? '#6BB88F' : '#D97373';
  final icon = success ? '&#10003;' : '&#10005;';
  final title = success ? 'Login concluído!' : 'Algo deu errado';
  final subtitle = success
      ? 'Você já pode fechar esta aba e voltar pro Flown.'
      : 'Feche esta aba e tente fazer login com Google de novo no Flown.';

  return '''
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>Flown</title>
<style>
  * { box-sizing: border-box; }
  body {
    margin: 0;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: -apple-system, "Segoe UI", Roboto, sans-serif;
    background: linear-gradient(135deg, #D4EEEC 0%, #E8F1F8 50%, #EBE6F3 100%);
  }
  .card {
    background: #ffffff;
    border-radius: 16px;
    border: 1px solid #DDE4EC;
    box-shadow: 0 12px 32px rgba(123, 163, 199, 0.18);
    padding: 40px 48px;
    text-align: center;
    max-width: 360px;
  }
  .icon {
    width: 56px;
    height: 56px;
    border-radius: 50%;
    background: $accentColor;
    color: #ffffff;
    font-size: 26px;
    line-height: 56px;
    margin: 0 auto 20px;
  }
  h1 {
    margin: 0 0 8px;
    font-size: 20px;
    color: #1A202C;
  }
  p {
    margin: 0;
    color: #6B7B8F;
    font-size: 14px;
    line-height: 1.5;
  }
</style>
</head>
<body>
  <div class="card">
    <div class="icon">$icon</div>
    <h1>$title</h1>
    <p>$subtitle</p>
  </div>
  <script>setTimeout(function () { try { window.close(); } catch (e) {} }, 1500);</script>
</body>
</html>
''';
}
