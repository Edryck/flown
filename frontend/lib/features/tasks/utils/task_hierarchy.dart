import '../../../core/models/task.dart';

/// `GET /tasks` devolve todas as tasks do usuário (top-level e subtasks
/// juntas — `findTasksByUser` no backend não filtra por `parentTaskId`), e
/// `TaskListController` guarda essa lista única. Esses helpers derivam a
/// hierarquia dela em memória, sem round-trip extra — o mesmo padrão de
/// `resolveStatusOrder`/`computeProjectStats` (sempre a partir da lista já
/// carregada, nunca uma busca própria).
///
/// Só 1 nível (tarefa → subtarefas diretas) de propósito — decisão do
/// `FLOWN_DOC.md` §14 ("recomendado 1 nível na UI, sem limite no backend").
/// `findSubtasks`/`softDeleteSubtasksByParentId`/
/// `permanentDeleteSubtasksByParentId` no `task.repository.ts` também são só
/// de 1 nível (sem recursão) — subtarefa-de-subtarefa exigiria tornar essas
/// 3 funções recursivas primeiro, pra não deixar tasks órfãs numa exclusão
/// em cascata.

/// Tasks de nível superior — usado pelas 3 views de listagem (Tabela/
/// Kanban/Calendário), que não devem mostrar subtarefas misturadas com
/// tasks normais.
List<Task> topLevelTasks(List<Task> tasks) =>
    tasks.where((t) => t.parentTaskId == null).toList();

/// Subtarefas diretas de [parent].
List<Task> subtasksOf(Task parent, List<Task> tasks) =>
    tasks.where((t) => t.parentTaskId == parent.id).toList();

/// Vencimento "efetivo" de uma task — o próprio, se ela não for subtarefa;
/// senão, o da tarefa-mãe. Subtarefa não tem vencimento independente: se o
/// pai venceu, ela venceu também — o backend já força `dueDate: null` em
/// qualquer subtarefa
/// (`task.service.ts`), então na prática `task.dueDate` de uma subtarefa é
/// sempre `null` e esse helper resolve pro valor que importa de verdade.
DateTime? effectiveDueDate(Task task, List<Task> tasks) {
  if (task.parentTaskId == null) return task.dueDate;
  final parent = tasks.where((t) => t.id == task.parentTaskId).firstOrNull;
  return parent?.dueDate;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
