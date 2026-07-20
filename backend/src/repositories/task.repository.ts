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
  filters: { projectId?: string | null; isDeleted?: boolean; search?: string } = {}
) {
  return prisma.task.findMany({
    where: {
      userId,
      isDeleted: filters.isDeleted ?? false,
      ...(filters.projectId !== undefined ? { projectId: filters.projectId } : {}),
      ...(filters.search
        ? { OR: [{ title: { contains: filters.search } }, { description: { contains: filters.search } }] }
        : {}),
    },
    orderBy: { order: "asc" },
  });
}

export async function searchTasks(userId: string, query: string) {
  return prisma.task.findMany({
    where: {
      userId,
      isDeleted: false,
      OR: [{ title: { contains: query } }, { description: { contains: query } }],
    },
    orderBy: { updatedAt: "desc" },
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

export async function findTasksForDashboardWindow(userId: string, since: Date) {
  return prisma.task.findMany({
    where: {
      userId,
      isDeleted: false,
      OR: [{ createdAt: { gte: since } }, { completedAt: { gte: since } }],
    },
    select: { status: true, priority: true, createdAt: true, completedAt: true, dueDate: true },
  });
}

export async function findAllActiveTasksSnapshot(userId: string) {
  return prisma.task.findMany({
    where: { userId, isDeleted: false },
    select: { status: true, priority: true, dueDate: true, completedAt: true },
  });
}