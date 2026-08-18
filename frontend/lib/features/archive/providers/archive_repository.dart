import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/note.dart';
import '../../../core/models/project.dart';
import '../../../core/models/task.dart';

part 'archive_repository.g.dart';

/// Conteúdo combinado de `GET /archive` — projetos/tarefas/anotações com
/// `isArchived: true`. Mesmo formato de `TrashContents`
/// (`features/trash/providers/trash_repository.dart`).
class ArchiveContents {
  const ArchiveContents({required this.projects, required this.tasks, required this.notes});

  final List<Project> projects;
  final List<Task> tasks;
  final List<Note> notes;

  bool get isEmpty => projects.isEmpty && tasks.isEmpty && notes.isEmpty;

  factory ArchiveContents.fromJson(Map<String, dynamic> json) => ArchiveContents(
        projects: (json['projects'] as List<dynamic>).map((e) => Project.fromJson(e as Map<String, dynamic>)).toList(),
        tasks: (json['tasks'] as List<dynamic>).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList(),
        notes: (json['notes'] as List<dynamic>).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Fala com `/archive`. Desarquivar um item específico não é rota de
/// `/archive` — fica no repositório do próprio recurso
/// (`ProjectRepository.unarchive`, `TaskRepository.unarchive`, etc.),
/// chamado por `ArchiveListController`. Sem exclusão/"esvaziar" — arquivo
/// não é lixeira, item arquivado nunca é apagado sozinho.
class ArchiveRepository {
  ArchiveRepository(this._dio);

  final Dio _dio;

  Future<ArchiveContents> list() {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/archive');
      return ArchiveContents.fromJson(response.data!);
    });
  }
}

@riverpod
ArchiveRepository archiveRepository(ArchiveRepositoryRef ref) => ArchiveRepository(ref.watch(apiClientProvider));
