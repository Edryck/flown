// Usado em qualquer target sem `dart:io` (hoje so Web) - Web nao tem
// conceito de "minimizar pra bandeja", entao aqui e so um no-op.
Future<void> initDesktopBackgroundService() async {}
