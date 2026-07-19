import { AppError } from "../utils/errors.js";
import type { FocusSessionType } from "../generated/prisma/enums.js";
import { findTaskById } from "../repositories/task.repository.js";
import {
  completeFocusSession,
  createFocusSession,
  deleteFocusSession,
  findFocusSessionById,
  findFocusSessionsByUser,
  sumFocusDurationByUser,
  updateFocusSession,
} from "../repositories/focus-session.repository.js";

type FocusSessionInput = {
  type: FocusSessionType;
  durationSeconds: number;
  startedAt: Date;
  completedAt?: Date | null;
  taskId?: string | null;
};

async function assertTaskOwnership(taskId: string, userId: string) {
  const task = await findTaskById(taskId, userId);
  if (!task) {
    throw new AppError(404, "Task not found");
  }
}

export async function create(userId: string, data: FocusSessionInput) {
  if (data.taskId) {
    await assertTaskOwnership(data.taskId, userId);
  }
  return createFocusSession(userId, data);
}

export async function list(userId: string, filters: { taskId?: string; since?: Date } = {}) {
  return findFocusSessionsByUser(userId, filters);
}

export async function getById(id: string, userId: string) {
  const session = await findFocusSessionById(id, userId);
  if (!session) {
    throw new AppError(404, "Focus session not found");
  }
  return session;
}

export async function update(id: string, userId: string, data: Partial<FocusSessionInput>) {
  if (data.taskId) {
    await assertTaskOwnership(data.taskId, userId);
  }
  const session = await updateFocusSession(id, userId, data);
  if (!session) {
    throw new AppError(404, "Focus session not found");
  }
  return session;
}

export async function complete(id: string, userId: string, completedAt: Date = new Date()) {
  const session = await completeFocusSession(id, userId, completedAt);
  if (!session) {
    throw new AppError(404, "Focus session not found");
  }
  return session;
}

export async function remove(id: string, userId: string) {
  const session = await deleteFocusSession(id, userId);
  if (!session) {
    throw new AppError(404, "Focus session not found");
  }
}

export async function getTotalDuration(userId: string, since?: Date) {
  return sumFocusDurationByUser(userId, since);
}