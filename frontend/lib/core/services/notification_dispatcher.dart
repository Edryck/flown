// Dispara a notificação nativa do SO - só existe no Desktop (mesmo motivo
// de `desktop_background_service.dart`: a lib por trás importa `dart:io`).
export 'notification_dispatcher_stub.dart'
    if (dart.library.io) 'notification_dispatcher_io.dart';
