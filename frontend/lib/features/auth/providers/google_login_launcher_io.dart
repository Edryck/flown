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

String _responsePage({required bool success}) {
  final message = success
      ? 'Login concluído! Você já pode fechar esta aba e voltar pro Flown.'
      : 'Algo deu errado no login. Feche esta aba e tente de novo no Flown.';
  return '<!doctype html><html><body style="font-family: sans-serif; '
      'text-align: center; padding-top: 80px;"><p>$message</p></body></html>';
}
