import { AppError } from "../utils/errors.js";
import type { Priority } from "../generated/prisma/enums.js";
import { findProjectTypeById } from "../repositories/project-type.repository.js";
import { findProjectById } from "../repositories/project.repository.js";
import {
  createTask,
  findSubtasks,
  findTaskById,
  findTasksByUser,
  permanentDeleteSubtasksByParentId,
  permanentDeleteTask,
  reorderTasks,
  restoreTask,
  softDeleteSubtasksByParentId,
  softDeleteTask,
  updateTask,
} from "../repositories/task.repository.js";

type ChecklistItem = { text: string; done: boolean };

type TaskInput = {
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
};

async function assertProjectOwnership(projectId: string, userId: string) {
  const project = await findProjectById(projectId, userId);
  if (!project) {
    throw new AppError(404, "Project not found");
  }
  return project;
}

async function assertProjectStatus(projectId: string, userId: string, status: string) {
  const project = await assertProjectOwnership(projectId, userId);
  const type = await findProjectTypeById(project.typeId);
  const availableStatus = (type?.availableStatus as string[]) ?? [];
  if (!availableStatus.includes(status)) {
    throw new AppError(400, `Status "${status}" is not valid for this project`);
  }
}

async function assertParentTask(parentTaskId: string, userId: string) {
  const parent = await findTaskById(parentTaskId, userId);
  if (!parent) {
    throw new AppError(404, "Parent task not found");
  }
}

export async function create(userId: string, data: TaskInput) {
  if (data.projectId) {
    if (data.status) {
      await assertProjectStatus(data.projectId, userId, data.status);
    } else {
      await assertProjectOwnership(data.projectId, userId);
    }
  }
  if (data.parentTaskId) {
    await assertParentTask(data.parentTaskId, userId);
  }
  return createTask(userId, data);
}

export async function list(userId: string, filters: { projectId?: string | null; isDeleted?: boolean } = {}) {
  return findTasksByUser(userId, filters);
}

export async function getById(id: string, userId: string) {
  const task = await findTaskById(id, userId);
  if (!task) {
    throw new AppError(404, "Task not found");
  }
  return task;
}

export async function update(id: string, userId: string, data: Partial<TaskInput>) {
  const task = await findTaskById(id, userId);
  if (!task) {
    throw new AppError(404, "Task not found");
  }

  const projectId = data.projectId !== undefined ? data.projectId : task.projectId;
  if (projectId) {
    if (data.status) {
      await assertProjectStatus(projectId, userId, data.status);
    } else {
      await assertProjectOwnership(projectId, userId);
    }
  }
  if (data.parentTaskId) {
    await assertParentTask(data.parentTaskId, userId);
  }

  const updated = await updateTask(id, userId, data);
  if (!updated) {
    throw new AppError(404, "Task not found");
  }
  return updated;
}

export async function softDelete(id: string, userId: string) {
  const task = await findTaskById(id, userId);
  if (!task) {
    throw new AppError(404, "Task not found");
  }
  await softDeleteSubtasksByParentId(id, userId);
  return softDeleteTask(id, userId);
}

export async function restore(id: string, userId: string) {
  const task = await restoreTask(id, userId);
  if (!task) {
    throw new AppError(404, "Task not found");
  }
  return task;
}

export async function permanentDelete(id: string, userId: string) {
  const task = await findTaskById(id, userId);
  if (!task) {
    throw new AppError(404, "Task not found");
  }
  // parentTaskId usa onDelete: NoAction, o banco bloqueia o delete do pai
  // se ainda existir subtask referenciando ele, entao a subtask vai primeiro.
  await permanentDeleteSubtasksByParentId(id, userId);
  await permanentDeleteTask(id, userId);
}

export async function reorder(userId: string, items: { id: string; order: number }[]) {
  await reorderTasks(userId, items);
}

export async function listSubtasks(parentTaskId: string, userId: string) {
  const parent = await findTaskById(parentTaskId, userId);
  if (!parent) {
    throw new AppError(404, "Task not found");
  }
  return findSubtasks(parentTaskId, userId);
}