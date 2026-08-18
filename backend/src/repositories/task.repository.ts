import { prisma } from "../utils/prisma.js";
import type { Priority } from "../generated/prisma/enums.js";

type ChecklistItem = { text: string; done: boolean };

async function findOwnedTask(id: string, userId: string) {
  return prisma.task.findFirst({ where: { id, userId } });
}

export async function createTask(
  userId: string,
  data: {
    title: string;
    description?: string | null;
    status?: string;
    priority?: Priority;
    dueDate?: Date | null;
    progress?: number | null;
    estimatedTime?: string | null;
    tags?: string[];
    checklist?: ChecklistItem[];
    projectId?: string | null;
    parentTaskId?: string | null;
    completedAt?: Date | null;
  }
) {
  return prisma.task.create({ data: { ...data, userId } });
}

export async function findTasksByUser(
  userId: string,
  filters: { projectId?: string | null; isDeleted?: boolean; isArchived?: boolean; search?: string } = {}
) {
  return prisma.task.findMany({
    where: {
      userId,
      isDeleted: filters.isDeleted ?? false,
      isArchived: filters.isArchived ?? false,
      ...(filters.projectId !== undefined ? { projectId: filters.projectId } : {}),
      ...(filters.search
        ? { OR: [{ title: { contains: filters.search } }, { description: { contains: filters.search } }] }
        : {}),
    },
    orderBy: { order: "asc" },
  });
}

export async function searchTasks(userId: string, query: string) {
  // `tags` é Json no SQLite — o provider não suporta `string_contains`/
  // `array_contains` pra esse tipo (só Postgres/MySQL), então filtra em
  // memória em vez de no `where` do Prisma. Volume baixo (app pessoal, sem
  // paginação hoje), então buscar tudo do usuário e filtrar é aceitável.
  const tasks = await prisma.task.findMany({
    where: { userId, isDeleted: false },
    orderBy: { updatedAt: "desc" },
  });
  const q = query.toLowerCase();
  return tasks.filter((task) => {
    const tags = Array.isArray(task.tags) ? (task.tags as string[]) : [];
    return (
      task.title.toLowerCase().includes(q) ||
      (task.description ?? "").toLowerCase().includes(q) ||
      tags.some((tag) => tag.toLowerCase().includes(q))
    );
  });
}

export async function findTaskById(id: string, userId: string) {
  return findOwnedTask(id, userId);
}

export async function updateTask(
  id: string,
  userId: string,
  data: Partial<{
    title: string;
    description: string | null;
    status: string;
    priority: Priority;
    dueDate: Date | null;
    progress: number | null;
    estimatedTime: string | null;
    tags: string[];
    checklist: ChecklistItem[];
    projectId: string | null;
    parentTaskId: string | null;
    completedAt: Date | null;
  }>
) {
  const task = await findOwnedTask(id, userId);
  if (!task) return null;
  return prisma.task.update({ where: { id }, data });
}

export async function softDeleteTask(id: string, userId: string) {
  const task = await findOwnedTask(id, userId);
  if (!task) return null;
  return prisma.task.update({
    where: { id },
    data: { isDeleted: true, deletedAt: new Date() },
  });
}

export async function restoreTask(id: string, userId: string) {
  const task = await findOwnedTask(id, userId);
  if (!task) return null;
  return prisma.task.update({
    where: { id },
    data: { isDeleted: false, deletedAt: null },
  });
}

export async function permanentDeleteTask(id: string, userId: string) {
  const task = await findOwnedTask(id, userId);
  if (!task) return null;
  return prisma.task.delete({ where: { id } });
}

export async function archiveTask(id: string, userId: string) {
  const task = await findOwnedTask(id, userId);
  if (!task) return null;
  return prisma.task.update({
    where: { id },
    data: { isArchived: true, archivedAt: new Date() },
  });
}

export async function unarchiveTask(id: string, userId: string) {
  const task = await findOwnedTask(id, userId);
  if (!task) return null;
  return prisma.task.update({
    where: { id },
    data: { isArchived: false, archivedAt: null },
  });
}

export async function archiveSubtasksByParentId(parentTaskId: string, userId: string) {
  return prisma.task.updateMany({
    where: { parentTaskId, userId },
    data: { isArchived: true, archivedAt: new Date() },
  });
}

export async function archiveTasksByProjectId(projectId: string, userId: string) {
  return prisma.task.updateMany({
    where: { projectId, userId, isDeleted: false },
    data: { isArchived: true, archivedAt: new Date() },
  });
}

export async function unarchiveTasksByProjectId(projectId: string, userId: string) {
  return prisma.task.updateMany({
    where: { projectId, userId, isDeleted: false },
    data: { isArchived: false, archivedAt: null },
  });
}

// Sem `userId` de proposito, mesmo padrao de `findTasksApproachingDue` -
// roda num job periodico varrendo todo mundo de uma vez. So considera tasks
// de nivel superior (parentTaskId: null) porque subtasks nao tem timer
// proprio, elas vao junto quando a mae arquiva (task.service.archive). O
// corte de dias e por usuario (`user.taskArchiveDays`), entao a comparacao
// final acontece em memoria no service, nao aqui.
export async function findTasksEligibleForAutoArchive() {
  return prisma.task.findMany({
    where: {
      status: "Done", // == task.service.COMPLETED_STATUS - repo nao pode importar de service (ciclo)
      isArchived: false,
      isDeleted: false,
      parentTaskId: null,
      completedAt: { not: null },
    },
    include: { user: { select: { id: true, taskArchiveDays: true } } },
  });
}

export async function reorderTasks(userId: string, items: { id: string; order: number }[]) {
  return prisma.$transaction(
    items.map((item) =>
      prisma.task.updateMany({
        where: { id: item.id, userId },
        data: { order: item.order },
      })
    )
  );
}

export async function findSubtasks(parentTaskId: string, userId: string) {
  return prisma.task.findMany({
    where: { parentTaskId, userId, isDeleted: false },
    orderBy: { order: "asc" },
  });
}

export async function softDeleteSubtasksByParentId(parentTaskId: string, userId: string) {
  return prisma.task.updateMany({
    where: { parentTaskId, userId },
    data: { isDeleted: true, deletedAt: new Date() },
  });
}

export async function permanentDeleteSubtasksByParentId(parentTaskId: string, userId: string) {
  return prisma.task.deleteMany({ where: { parentTaskId, userId } });
}

export async function permanentDeleteTasksByProjectId(projectId: string, userId: string) {
  return prisma.task.deleteMany({ where: { projectId, userId } });
}

export async function softDeleteTasksByProjectId(projectId: string, userId: string) {
  return prisma.task.updateMany({
    where: { projectId, userId, isDeleted: false },
    data: { isDeleted: true, deletedAt: new Date() },
  });
}

// `parentTaskId: null` nas duas queries abaixo de proposito — subtarefas nao
// tem due date propria (sempre herdam do pai, ver task.service.ts) e nao
// contam como task independente, entao nao fazem sentido nas
// estatisticas/dashboard, so as tasks de nivel superior. Isso alimenta tanto
// `GET /dashboard/stats` quanto o heatmap/grafico mensal da tela de
// Estatisticas, ja que os dois vem dessas mesmas duas funcoes.
export async function findTasksForDashboardWindow(userId: string, since: Date) {
  return prisma.task.findMany({
    where: {
      userId,
      isDeleted: false,
      parentTaskId: null,
      OR: [{ createdAt: { gte: since } }, { completedAt: { gte: since } }],
    },
    select: { status: true, priority: true, createdAt: true, completedAt: true, dueDate: true },
  });
}

export async function findAllActiveTasksSnapshot(userId: string) {
  return prisma.task.findMany({
    where: { userId, isDeleted: false, parentTaskId: null },
    select: { status: true, priority: true, dueDate: true, completedAt: true },
  });
}

// Sem `userId` de proposito — roda num job periodico do servidor (nao numa
// requisicao de um usuario especifico), varrendo todo mundo de uma vez.
// `maxWindowHours` e o maior estagio de lembrete (24h) — o service decide,
// task por task, quais estagios menores (12/6/1h) ja foram cruzados
// olhando `remindersSent`.
export async function findTasksApproachingDue(maxWindowHours: number) {
  const now = new Date();
  const threshold = new Date(now.getTime() + maxWindowHours * 60 * 60 * 1000);

  return prisma.task.findMany({
    where: {
      isDeleted: false,
      completedAt: null,
      parentTaskId: null,
      dueDate: { gte: now, lte: threshold },
    },
    include: {
      user: { select: { id: true, name: true, email: true } },
      project: { select: { name: true } },
    },
  });
}

export async function updateTaskRemindersSent(id: string, remindersSent: number[]) {
  return prisma.task.update({ where: { id }, data: { remindersSent } });
}

export async function countCompletedTasksInRange(userId: string, start: Date, end: Date) {
  return prisma.task.count({
    where: { userId, isDeleted: false, parentTaskId: null, completedAt: { gte: start, lt: end } },
  });
}