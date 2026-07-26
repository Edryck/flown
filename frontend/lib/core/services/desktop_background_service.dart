// Bandeja do sistema + intercepta o botao de fechar - so existe no Desktop
// (window_manager/tray_manager/local_notifier importam dart:io, entao nao
// podem entrar direto num arquivo compartilhado com a Web). O Dart escolhe
// o arquivo certo em tempo de compilacao via `dart.library.io`.
export 'desktop_background_service_stub.dart'
    if (dart.library.io) 'desktop_background_service_io.dart';
