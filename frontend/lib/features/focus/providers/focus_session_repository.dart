import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/focus_session.dart';
import '../../../core/models/focus_session_type.dart';

part 'focus_session_repository.g.dart';

/// Fala com `/sessions`. Só `create` por enquanto — o Modo Foco sempre
/// registra a sessão já fechada (com `durationSeconds`/`completedAt`
/// conhecidos) no momento em que o cronômetro para, em vez de criar um
/// registro "em andamento" e completá-lo depois (`POST` + `.../complete`
/// existem no backend, mas essa segunda etapa não tem uso aqui — ver
/// `focus_screen.dart`).
class FocusSessionRepository {
  FocusSessionRepository(this._dio);

  final Dio _dio;

  Future<FocusSession> create({
    required FocusSessionKind type,
    required int durationSeconds,
    required DateTime startedAt,
    required DateTime completedAt,
    String? taskId,
  }) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/sessions',
        data: {
          'type': type.wireValue,
          'durationSeconds': durationSeconds,
          'startedAt': startedAt.toIso8601String(),
          'completedAt': completedAt.toIso8601String(),
          if (taskId != null) 'taskId': taskId,
        },
      );
      return FocusSession.fromJson(response.data!);
    });
  }
}

@riverpod
FocusSessionRepository focusSessionRepository(FocusSessionRepositoryRef ref) =>
    FocusSessionRepository(ref.watch(apiClientProvider));
