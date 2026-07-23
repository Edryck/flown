import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/project.dart';
import 'project_repository.dart';

part 'project_list_controller.g.dart';

/// Lista de projetos do usuário + operações de mutação. Substitui o antigo
/// `projectListProvider` (só leitura) — telas que precisam de nome/cor de
/// projeto (ex: `TasksScreen`, `TaskFormDialog`) e a própria tela de
/// Projects leem por aqui, nunca chamam `ProjectRepository` direto.
@riverpod
class ProjectListController extends _$ProjectListController {
  @override
  FutureOr<List<Project>> build() {
    return ref.watch(projectRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(projectRepositoryProvider).list());
  }

  Future<Project> create(ProjectInput input) async {
    final project = await ref.read(projectRepositoryProvider).create(input);
    state = AsyncData([...?state.valueOrNull, project]);
    return project;
  }

  /// Nome `updateProject` (não `update`) de propósito — `AsyncNotifier` já
  /// tem um método `update` embutido com assinatura incompatível.
  Future<Project> updateProject(String id, ProjectInput input) async {
    final project = await ref.read(projectRepositoryProvider).update(id, input);
    state = AsyncData([for (final p in state.valueOrNull ?? const <Project>[]) if (p.id == id) project else p]);
    return project;
  }

  Future<void> delete(String id) async {
    await ref.read(projectRepositoryProvider).softDelete(id);
    state = AsyncData([for (final p in state.valueOrNull ?? const <Project>[]) if (p.id != id) p]);
  }
}
