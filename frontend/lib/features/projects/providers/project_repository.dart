import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/project.dart';

part 'project_repository.g.dart';

/// Sentinela pra distinguir "campo não enviado no PATCH" de "campo enviado
/// como null" — mesma ideia de `Unset`/`unset` em `task_repository.dart`.
class ProjectFieldUnset {
  const ProjectFieldUnset._();
}

const projectFieldUnset = ProjectFieldUnset._();

/// Corpo de `POST`/`PATCH /projects` (espelha `createProjectSchema`/
/// `updateProjectSchema`, `backend/src/schemas/project.schema.ts`).
class ProjectInput {
  const ProjectInput({
    this.name = projectFieldUnset,
    this.description = projectFieldUnset,
    this.color = projectFieldUnset,
    this.typeId = projectFieldUnset,
  });

  final Object? name;
  final Object? description;
  final Object? color;
  final Object? typeId;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value is ProjectFieldUnset) return;
      json[key] = value;
    }

    put('name', name);
    put('description', description);
    put('color', color);
    put('typeId', typeId);
    return json;
  }
}

/// Fala com `/projects`. Nunca chamado direto pelas telas — sempre por trás
/// de `ProjectListController`, que mantém a lista em memória sincronizada.
class ProjectRepository {
  ProjectRepository(this._dio);

  final Dio _dio;

  Future<List<Project>> list() {
    return guardApiCall(() async {
      final response = await _dio.get<List<dynamic>>('/projects');
      return response.data!.map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  Future<Project> create(ProjectInput input) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>('/projects', data: input.toJson());
      return Project.fromJson(response.data!);
    });
  }

  Future<Project> update(String id, ProjectInput input) {
    return guardApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>('/projects/$id', data: input.toJson());
      return Project.fromJson(response.data!);
    });
  }

  Future<Project> softDelete(String id) {
    return guardApiCall(() async {
      final response = await _dio.delete<Map<String, dynamic>>('/projects/$id');
      return Project.fromJson(response.data!);
    });
  }

  Future<Project> restore(String id) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>('/projects/$id/restore');
      return Project.fromJson(response.data!);
    });
  }

  Future<void> permanentDelete(String id) {
    return guardApiCall(() => _dio.delete('/projects/$id/permanent'));
  }
}

@riverpod
ProjectRepository projectRepository(ProjectRepositoryRef ref) => ProjectRepository(ref.watch(apiClientProvider));
