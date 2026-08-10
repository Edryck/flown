import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/checklist_item.dart';
import '../../../core/models/task.dart';
import '../../../core/models/task_priority.dart';

part 'task_repository.g.dart';

/// Sentinela pra distinguir "campo não enviado no PATCH" de "campo enviado
/// como null" (limpar um valor opcional, ex: remover prazo/projeto de uma
/// task) — named params comuns não conseguem expressar essa diferença só
/// com `null` do Dart.
class Unset {
  const Unset._();
}

const unset = Unset._();

/// Corpo de `POST`/`PATCH /tasks` (espelha `createTaskSchema`/
/// `updateTaskSchema`, `backend/src/schemas/task.schema.ts`). Só os campos
/// diferentes de `unset` entram no JSON enviado.
class TaskInput {
  const TaskInput({
    this.title = unset,
    this.description = unset,
    this.status = unset,
    this.priority = unset,
    this.dueDate = unset,
    this.progress = unset,
    this.estimatedTime = unset,
    this.tags = unset,
    this.checklist = unset,
    this.projectId = unset,
    this.parentTaskId = unset,
  });

  final Object? title;
  final Object? description;
  final Object? status;
  final Object? priority;
  final Object? dueDate;
  final Object? progress;
  final Object? estimatedTime;
  final Object? tags;
  final Object? checklist;
  final Object? projectId;
  final Object? parentTaskId;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    void put(String key, Object? value, Object? Function(Object? v) encode) {
      if (value is Unset) return;
      json[key] = encode(value);
    }

    put('title', title, (v) => v);
    put('description', description, (v) => v);
    put('status', status, (v) => v);
    put('priority', priority, (v) => (v as TaskPriority?)?.wireValue);
    put('dueDate', dueDate, (v) => (v as DateTime?)?.toUtc().toIso8601String());
    put('progress', progress, (v) => v);
    put('estimatedTime', estimatedTime, (v) => v);
    put('tags', tags, (v) => v);
    put('checklist', checklist, (v) => (v as List<ChecklistItem>?)?.map((c) => c.toJson()).toList());
    put('projectId', projectId, (v) => v);
    put('parentTaskId', parentTaskId, (v) => v);
    return json;
  }
}

/// Fala com `/tasks/*`. Nunca chamado direto pelas telas — sempre por trás
/// de `TaskListController`, que mantém a lista em memória sincronizada.
class TaskRepository {
  TaskRepository(this._dio);

  final Dio _dio;

  Future<List<Task>> list({String? projectId, String? q, bool? isDeleted}) {
    return guardApiCall(() async {
      final response = await _dio.get<List<dynamic>>(
        '/tasks',
        queryParameters: {
          'projectId': ?projectId,
          if (q != null && q.isNotEmpty) 'q': q,
          if (isDeleted != null) 'isDeleted': isDeleted.toString(),
        },
      );
      return response.data!.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  Future<Task> create(TaskInput input) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>('/tasks', data: input.toJson());
      return Task.fromJson(response.data!);
    });
  }

  Future<Task> update(String id, TaskInput input) {
    return guardApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>('/tasks/$id', data: input.toJson());
      return Task.fromJson(response.data!);
    });
  }

  Future<Task> softDelete(String id) {
    return guardApiCall(() async {
      final response = await _dio.delete<Map<String, dynamic>>('/tasks/$id');
      return Task.fromJson(response.data!);
    });
  }

  Future<Task> restore(String id) {
    return guardApiCall(() async {
      final response = await _dio.post<Map<String, dynamic>>('/tasks/$id/restore');
      return Task.fromJson(response.data!);
    });
  }

  Future<void> permanentDelete(String id) {
    return guardApiCall(() => _dio.delete('/tasks/$id/permanent'));
  }
}

@riverpod
TaskRepository taskRepository(TaskRepositoryRef ref) => TaskRepository(ref.watch(apiClientProvider));
