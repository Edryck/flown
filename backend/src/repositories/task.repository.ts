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
  }
) {
  return prisma.task.create({ data: { ...data, userId } });
}

export async function findTasksByUser(
  userId: string,
  filters: { projectId?: string | null; isDeleted?: boolean } = {}
) {
  return prisma.task.findMany({
    where: {
      userId,
      isDeleted: filters.isDeleted ?? false,
      ...(filters.projectId !== undefined ? { projectId: filters.projectId } : {}),
    },
    orderBy: { order: "asc" },
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

export async function softDeleteManyTasks(ids: string[], userId: string) {
  return prisma.task.updateMany({
    where: { id: { in: ids }, userId },
    data: { isDeleted: true, deletedAt: new Date() },
  });
}