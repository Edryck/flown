import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/task.dart';
import 'task_repository.dart';

part 'task_list_controller.g.dart';

/// Lista de tasks não deletadas do usuário + operações de mutação. As 3
/// views de Tasks e o TaskForm sempre leem/escrevem por aqui, nunca chamam
/// `TaskRepository` direto — mantém a lista em memória sempre consistente
/// com o que foi persistido no backend, sem cada tela precisar refazer
/// fetch depois de uma mutação.
///
/// `keepAlive: true` de propósito — sem isso (`@riverpod` puro é
/// `autoDispose`), navegar pra uma tela que não observa esse provider (ex:
/// Notas, Configurações) descartava a lista, e voltar pra uma tela que
/// observa (Tasks, Projects — que usa a lista de tasks pras estatísticas de
/// cada projeto) refazia o fetch inteiro do zero, com spinner de novo. Como
/// toda mutação já atualiza `state` localmente (`create`/`updateTask`/etc
/// abaixo), manter vivo não arrisca dado desatualizado — é sempre o mesmo
/// usuário, sem outro cliente escrevendo por baixo.
@Riverpod(keepAlive: true)
class TaskListController extends _$TaskListController {
  @override
  FutureOr<List<Task>> build() {
    return ref.watch(taskRepositoryProvider).list(isDeleted: false);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(taskRepositoryProvider).list(isDeleted: false),
    );
  }

  Future<Task> create(TaskInput input) async {
    final task = await ref.read(taskRepositoryProvider).create(input);
    state = AsyncData([...?state.valueOrNull, task]);
    return task;
  }

  /// Nome `updateTask` (não `update`) de propósito — `AsyncNotifier` já tem
  /// um método `update` embutido (recalcula o estado a partir do estado
  /// atual), com assinatura incompatível com essa.
  Future<Task> updateTask(String id, TaskInput input) async {
    final task = await ref.read(taskRepositoryProvider).update(id, input);

    if (task.parentTaskId != null) {
      // Atualizar uma subtask recalcula o progresso da tarefa-mãe no
      // backend (subtasks + checklist dela, ver task.service.ts) — a
      // resposta desta chamada só traz a subtask em si, então recarrega a
      // lista toda pra pegar o valor novo do pai também (sem isso, a barra
      // de progresso da mãe ficava travada no valor antigo até um refresh
      // manual).
      await refresh();
      return task;
    }

    state = AsyncData([
      for (final t in state.valueOrNull ?? const <Task>[])
        if (t.id == id) task else t,
    ]);
    return task;
  }

  /// Atalho usado pelo drag-and-drop do Kanban — só muda `status`.
  Future<Task> updateStatus(String id, String status) {
    return updateTask(id, TaskInput(status: status));
  }

  Future<void> delete(String id) async {
    await ref.read(taskRepositoryProvider).softDelete(id);
    state = AsyncData([
      for (final t in state.valueOrNull ?? const <Task>[])
        if (t.id != id) t,
    ]);
  }
}
