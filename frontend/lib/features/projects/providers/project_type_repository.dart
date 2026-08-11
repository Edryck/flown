import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/project_type.dart';

part 'project_type_repository.g.dart';

/// Fala com `/project-types`. Só listagem — criação de tipo é operação de
/// setup (seed `general`/`software`), sem tela prevista.
class ProjectTypeRepository {
  ProjectTypeRepository(this._dio);

  final Dio _dio;

  Future<List<ProjectType>> list() {
    return guardApiCall(() async {
      final response = await _dio.get<List<dynamic>>('/project-types');
      return response.data!.map((e) => ProjectType.fromJson(e as Map<String, dynamic>)).toList();
    });
  }
}

@riverpod
ProjectTypeRepository projectTypeRepository(ProjectTypeRepositoryRef ref) =>
    ProjectTypeRepository(ref.watch(apiClientProvider));

/// Lista de tipos de projeto — usada pelo TaskForm pra resolver, a partir do
/// projeto selecionado (`Project.typeId`), a lista de status válidos
/// (`ProjectType.availableStatus`) pro Select de status.
///
/// `keepAlive: true` — dado essencialmente estático (só muda por um setup
/// administrativo, nunca pela sessão normal do usuário) e observado em
/// telas espalhadas (Tasks, Focus, TaskForm) — sem isso, cada uma refazia
/// esse fetch sempre que era a primeira a montar depois de um tempo sem
/// nenhuma tela observando.
@Riverpod(keepAlive: true)
Future<List<ProjectType>> projectTypeList(ProjectTypeListRef ref) {
  return ref.watch(projectTypeRepositoryProvider).list();
}
