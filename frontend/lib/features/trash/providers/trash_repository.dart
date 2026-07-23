import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/note.dart';
import '../../../core/models/project.dart';
import '../../../core/models/task.dart';

part 'trash_repository.g.dart';

/// Conteúdo combinado de `GET /trash` — projetos/tarefas/anotações com
/// `isDeleted: true`.
class TrashContents {
  const TrashContents({required this.projects, required this.tasks, required this.notes});

  final List<Project> projects;
  final List<Task> tasks;
  final List<Note> notes;

  bool get isEmpty => projects.isEmpty && tasks.isEmpty && notes.isEmpty;

  factory TrashContents.fromJson(Map<String, dynamic> json) => TrashContents(
        projects: (json['projects'] as List<dynamic>).map((e) => Project.fromJson(e as Map<String, dynamic>)).toList(),
        tasks: (json['tasks'] as List<dynamic>).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList(),
        notes: (json['notes'] as List<dynamic>).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Fala com `/trash`. Restaurar/excluir definitivamente um item específico
/// não são rotas de `/trash` — ficam nos repositórios do próprio recurso
/// (`ProjectRepository.restore`, `TaskRepository.permanentDelete`, etc.),
/// chamados por `TrashListController`.
class TrashRepository {
  TrashRepository(this._dio);

  final Dio _dio;

  Future<TrashContents> list() {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/trash');
      return TrashContents.fromJson(response.data!);
    });
  }

  Future<void> emptyTrash() {
    return guardApiCall(() => _dio.delete('/trash/empty'));
  }
}

@riverpod
TrashRepository trashRepository(TrashRepositoryRef ref) => TrashRepository(ref.watch(apiClientProvider));
