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

/// Tradução pra português dos status seedados (`ProjectType.availableStatus`
/// dos tipos "software"/"general", `backend/prisma/seed.ts`) — só pra
/// exibição (badges, legendas, dropdowns); o valor enviado/recebido da API
/// continua em inglês, que é o que `ProjectType.availableStatus` valida. Um
/// status customizado de um `ProjectType` futuro que não bata com nenhuma
/// chave aqui aparece sem tradução (texto cru do backend) — mesma
/// degradação graciosa que `StatusBadge` já tinha antes de traduzir.
const statusLabelsPtBr = {
  'Backlog': 'Pendente',
  'Todo': 'A Fazer',
  'In Progress': 'Em Andamento',
  'In Review': 'Em Revisão',
  'Blocked': 'Bloqueado',
  'Done': 'Concluído',
  'Cancelled': 'Cancelado',
};

String statusLabelPtBr(String status) => statusLabelsPtBr[status] ?? status;
