import '../../../core/models/project_type.dart';
import '../../../core/models/task.dart';

/// Ordem estável de status usada pras colunas do Kanban (`TasksKanbanView`)
/// e pra cor consistente de cada status nas 3 views
/// (`StatusBadge.colorIndex`).
///
/// Primeiro entram todos os status de `ProjectType.availableStatus` (todos
/// os tipos de projeto cadastrados, não só os já usados) — assim as colunas
/// do Kanban ficam prontas mesmo sem nenhuma task/projeto criado ainda.
/// Depois entra qualquer status "órfão" que apareça numa task sem projeto
/// (não validado contra nenhum `ProjectType`, ver `task.service.ts`), pra
/// nenhuma task ficar sem coluna/cor.
List<String> resolveStatusOrder(Iterable<ProjectType> projectTypes, Iterable<Task> tasks) {
  final seen = <String>[];
  for (final type in projectTypes) {
    for (final status in type.availableStatus) {
      if (!seen.contains(status)) seen.add(status);
    }
  }
  for (final task in tasks) {
    if (!seen.contains(task.status)) seen.add(task.status);
  }
  return seen;
}
