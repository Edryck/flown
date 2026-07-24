import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/note.dart';
import '../../../core/models/project.dart';
import '../../../core/models/task.dart';

part 'search_repository.g.dart';

/// Espelha a resposta de `GET /search?q=` (`search.controller.ts`) — os 3
/// grupos que a busca global devolve (projects/tasks/notes). Não é uma tela
/// própria: alimenta o dropdown de resultados da `TopNavBar`.
class SearchResults {
  const SearchResults({required this.projects, required this.tasks, required this.notes});

  final List<Project> projects;
  final List<Task> tasks;
  final List<Note> notes;

  bool get isEmpty => projects.isEmpty && tasks.isEmpty && notes.isEmpty;

  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
        projects: (json['projects'] as List<dynamic>).map((e) => Project.fromJson(e as Map<String, dynamic>)).toList(),
        tasks: (json['tasks'] as List<dynamic>).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList(),
        notes: (json['notes'] as List<dynamic>).map((e) => Note.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class SearchRepository {
  SearchRepository(this._dio);

  final Dio _dio;

  Future<SearchResults> search(String query) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/search', queryParameters: {'q': query});
      return SearchResults.fromJson(response.data!);
    });
  }
}

@riverpod
SearchRepository searchRepository(SearchRepositoryRef ref) => SearchRepository(ref.watch(apiClientProvider));