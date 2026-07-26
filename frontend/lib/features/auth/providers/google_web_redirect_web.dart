import 'package:web/web.dart' as web;

// Origem atual da pagina (ex: "http://localhost:54321") — usada pra montar
// o `webRedirect` que o backend devolve depois do login no Google.
String currentWebOrigin() => web.window.location.origin;

// Navegacao de pagina inteira (nao um push do go_router) — o browser
// literalmente sai do app Flutter, vai pro Google, e so volta quando o
// backend redireciona de volta pra essa mesma origem.
void redirectToWebUrl(String url) {
  web.window.location.href = url;
}
