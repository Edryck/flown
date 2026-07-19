import { prisma } from "../utils/prisma.js";
import type { FocusSessionType } from "../generated/prisma/enums.js";

async function findOwnedFocusSession(id: string, userId: string) {
  return prisma.focusSession.findFirst({ where: { id, userId } });
}

export async function createFocusSession(
  userId: string,
  data: {
    type: FocusSessionType;
    durationSeconds: number;
    startedAt: Date;
    completedAt?: Date | null;
    taskId?: string | null;
  }
) {
  return prisma.focusSession.create({ data: { ...data, userId } });
}

export async function findFocusSessionsByUser(
  userId: string,
  filters: { taskId?: string; since?: Date } = {}
) {
  return prisma.focusSession.findMany({
    where: {
      userId,
      ...(filters.taskId ? { taskId: filters.taskId } : {}),
      ...(filters.since ? { startedAt: { gte: filters.since } } : {}),
    },
    orderBy: { startedAt: "desc" },
  });
}

export async function findFocusSessionById(id: string, userId: string) {
  return findOwnedFocusSession(id, userId);
}

export async function updateFocusSession(
  id: string,
  userId: string,
  data: Partial<{
    type: FocusSessionType;
    durationSeconds: number;
    startedAt: Date;
    completedAt: Date | null;
    taskId: string | null;
  }>
) {
  const session = await findOwnedFocusSession(id, userId);
  if (!session) return null;
  return prisma.focusSession.update({ where: { id }, data });
}

export async function completeFocusSession(id: string, userId: string, completedAt: Date) {
  const session = await findOwnedFocusSession(id, userId);
  if (!session) return null;
  return prisma.focusSession.update({ where: { id }, data: { completedAt } });
}

export async function deleteFocusSession(id: string, userId: string) {
  const session = await findOwnedFocusSession(id, userId);
  if (!session) return null;
  return prisma.focusSession.delete({ where: { id } });
}

export async function sumFocusDurationByUser(userId: string, since?: Date) {
  return prisma.focusSession.aggregate({
    where: { userId, ...(since ? { startedAt: { gte: since } } : {}) },
    _sum: { durationSeconds: true },
    _count: true,
  });
}