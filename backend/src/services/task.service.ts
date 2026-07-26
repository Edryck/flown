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
import { createNotification } from "../repositories/notification.repository.js";

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

// Nao existe enum/flag de "concluida" no schema — "Done" e o unico status em
// comum entre os dois ProjectType seedados (software/general), entao serve
// como a convencao de "task concluida" pro Dashboard (log 09).
export const COMPLETED_STATUS = "Done";

// Progresso implicito por status, usado so quando a task NAO tem subtasks
// (com subtasks, o progresso vem da % delas concluidas — ver
// computeProgressFromSubtasks) e o caller nao mandou um `progress` proprio
// na mesma requisicao (form com checklist, por exemplo, sempre manda o dele
// e tem prioridade). Cobre so os status dos ProjectType seedados
// (backend/prisma/seed.ts) — um status customizado sem entrada aqui nao
// altera o progresso.
const STATUS_PROGRESS: Record<string, number> = {
  Backlog: 0,
  Todo: 0,
  "In Progress": 50,
  "In Review": 75,
  Done: 100,
};

// Subtasks e itens do checklist contam como unidades iguais de progresso —
// uma task com 2 subtasks (1 concluida) e um checklist de 2 itens (1
// marcado) fica em 50% (2 de 4), nao só a % das subtasks.
function computeCombinedProgress(
  checklist: ChecklistItem[],
  subtasks: { status: string }[]
): number | null {
  const totalUnits = checklist.length + subtasks.length;
  if (totalUnits === 0) return null;
  const doneChecklist = checklist.filter((item) => item.done).length;
  const doneSubtasks = subtasks.filter((t) => t.status === COMPLETED_STATUS).length;
  return Math.round(((doneChecklist + doneSubtasks) / totalUnits) * 100);
}

async function computeProgressFromSubtasks(parentId: string, userId: string, checklist: ChecklistItem[]) {
  const subtasks = await findSubtasks(parentId, userId);
  return computeCombinedProgress(checklist, subtasks);
}

/// Progresso implicito quando o caller nao mandou um valor proprio: prioriza
/// subtasks+checklist reais (% delas concluidas) sobre o mapeamento por
/// status — uma task com subtasks/checklist tem uma medida de progresso
/// mais precisa que "In Progress = 50%".
async function resolveImplicitProgress(
  taskId: string,
  userId: string,
  status: string | undefined,
  checklist: ChecklistItem[]
): Promise<number | undefined> {
  const combinedProgress = await computeProgressFromSubtasks(taskId, userId, checklist);
  if (combinedProgress !== null) return combinedProgress;
  if (status !== undefined) return STATUS_PROGRESS[status];
  return undefined;
}

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
  const completedAt = data.status === COMPLETED_STATUS ? new Date() : null;
  // Subtarefa nao tem vencimento proprio — herda o da tarefa-mae (se o pai
  // venceu, ela venceu tambem). Ignora qualquer dueDate que o caller mande
  // junto com um parentTaskId.
  const dueDate = data.parentTaskId ? null : data.dueDate;
  return createTask(userId, { ...data, dueDate, completedAt });
}

export async function list(
  userId: string,
  filters: { projectId?: string | null; isDeleted?: boolean; search?: string; tag?: string } = {}
) {
  const { tag, ...repositoryFilters } = filters;
  const tasks = await findTasksByUser(userId, repositoryFilters);
  if (!tag) return tasks;
  return tasks.filter((task) => (task.tags as string[]).includes(tag));
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

  // Mesma regra do create() — subtarefa nunca tem vencimento proprio, so o
  // da tarefa-mae. `isSubtask` considera tanto uma task que ja era subtask
  // quanto uma que esta virando subtask nesta mesma requisicao; forca
  // `dueDate: null` mesmo que o caller tenha mandado um valor junto.
  const isSubtask = Boolean(data.parentTaskId !== undefined ? data.parentTaskId : task.parentTaskId);

  let completedAt: Date | null | undefined;
  const statusChanged = Boolean(data.status && data.status !== task.status);
  if (statusChanged) {
    completedAt = data.status === COMPLETED_STATUS ? new Date() : null;
  }

  // So calcula quando o caller nao mandou um `progress` proprio na mesma
  // requisicao (form com checklist sempre manda o dele, e tem prioridade) —
  // sem isso, uma task sem subtasks/checklist ficava com `completedAt`
  // setado mas a barra de progresso parada no valor antigo (bug reportado:
  // só tasks com subtasks/checklist atualizavam o progresso ao mudar de
  // status).
  const effectiveChecklist = (data.checklist ?? task.checklist) as ChecklistItem[];
  const progress =
    data.progress !== undefined
      ? data.progress
      : (await resolveImplicitProgress(id, userId, data.status, effectiveChecklist)) ?? undefined;

  const updated = await updateTask(id, userId, {
    ...data,
    ...(progress !== undefined ? { progress } : {}),
    ...(completedAt !== undefined ? { completedAt } : {}),
    ...(isSubtask ? { dueDate: null } : {}),
  });
  if (!updated) {
    throw new AppError(404, "Task not found");
  }

  if (statusChanged) {
    await createNotification({
      userId,
      type: "status_changed",
      taskId: id,
      payload: { taskTitle: task.title, oldStatus: task.status, newStatus: data.status },
    });
  }

  // Se essa task e subtask de outra, o progresso do pai (subtasks + checklist
  // proprio dele) pode ter mudado — recalcula e persiste.
  if (updated.parentTaskId) {
    const parent = await findTaskById(updated.parentTaskId, userId);
    if (parent) {
      const parentProgress = await computeProgressFromSubtasks(
        updated.parentTaskId,
        userId,
        parent.checklist as ChecklistItem[]
      );
      if (parentProgress !== null) {
        await updateTask(updated.parentTaskId, userId, { progress: parentProgress });
      }
    }
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