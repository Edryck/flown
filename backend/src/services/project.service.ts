import { AppError } from "../utils/errors.js";
import { findProjectTypeById } from "../repositories/project-type.repository.js";
import {
  archiveProject,
  completeProject,
  createProject,
  findProjectById,
  findProjectsByUser,
  findProjectsEligibleForAutoArchive,
  permanentDeleteProject,
  restoreProject,
  softDeleteProject,
  unarchiveProject,
  updateProject,
  updateProjectCompletedAt,
} from "../repositories/project.repository.js";
import {
  archiveTasksByProjectId,
  permanentDeleteTasksByProjectId,
  softDeleteTasksByProjectId,
  unarchiveTasksByProjectId,
} from "../repositories/task.repository.js";
import {
  archiveNotesByProjectId,
  permanentDeleteNotesByProjectId,
  softDeleteNotesByProjectId,
  unarchiveNotesByProjectId,
} from "../repositories/note.repository.js";
import { createNotification } from "../repositories/notification.repository.js";

type ProjectInput = {
  name: string;
  description?: string | null;
  color: string;
  typeId: string;
};

async function assertProjectType(typeId: string) {
  const type = await findProjectTypeById(typeId);
  if (!type) {
    throw new AppError(400, "Invalid project type");
  }
  return type;
}

export async function create(userId: string, data: ProjectInput) {
  await assertProjectType(data.typeId);
  return createProject(userId, data);
}

export async function list(
  userId: string,
  filters: { isDeleted?: boolean; isArchived?: boolean; search?: string } = {}
) {
  return findProjectsByUser(userId, filters);
}

export async function getById(id: string, userId: string) {
  const project = await findProjectById(id, userId);
  if (!project) {
    throw new AppError(404, "Project not found");
  }
  return project;
}

export async function update(id: string, userId: string, data: Partial<ProjectInput>) {
  if (data.typeId) {
    await assertProjectType(data.typeId);
  }
  const project = await updateProject(id, userId, data);
  if (!project) {
    throw new AppError(404, "Project not found");
  }
  return project;
}

export async function softDelete(id: string, userId: string) {
  const project = await softDeleteProject(id, userId);
  if (!project) {
    throw new AppError(404, "Project not found");
  }
  // Mesma logica do task.service.softDelete cascateando pra subtask: sem isso,
  // as tasks/notas do projeto continuam "vivas" fora da lixeira mesmo com o
  // projeto trashado, e um DELETE /trash/empty as apagaria de surpresa (o
  // permanentDelete de projeto cascateia tasks/notas independente de isDeleted).
  await softDeleteTasksByProjectId(id, userId);
  await softDeleteNotesByProjectId(id, userId);
  return project;
}

export async function restore(id: string, userId: string) {
  const project = await restoreProject(id, userId);
  if (!project) {
    throw new AppError(404, "Project not found");
  }
  return project;
}

export async function permanentDelete(id: string, userId: string) {
  const project = await findProjectById(id, userId);
  if (!project) {
    throw new AppError(404, "Project not found");
  }
  // Task.project e Note.project usam onDelete: SetNull no schema, nao Cascade
  // o banco NAO apaga tasks/notes sozinho, entao a cascata tem que ser feita aqui.
  await permanentDeleteTasksByProjectId(id, userId);
  await permanentDeleteNotesByProjectId(id, userId);
  await permanentDeleteProject(id, userId);
}

export async function archive(id: string, userId: string) {
  const project = await archiveProject(id, userId);
  if (!project) {
    throw new AppError(404, "Project not found");
  }
  // Cascata: toda task (e subtasks, que compartilham o mesmo projectId da
  // mae) e nota do projeto arquivam junto - mesma logica do softDelete
  // cascateando pra tasks/notas do projeto.
  await archiveTasksByProjectId(id, userId);
  await archiveNotesByProjectId(id, userId);
  return project;
}

export async function unarchive(id: string, userId: string) {
  const project = await findProjectById(id, userId);
  if (!project) {
    throw new AppError(404, "Project not found");
  }
  const unarchived = await unarchiveProject(id, userId);
  if (!unarchived) {
    throw new AppError(404, "Project not found");
  }
  // Simetrico ao archive(): desarquiva as tasks/notas que foram arquivadas
  // em cascata junto com o projeto.
  await unarchiveTasksByProjectId(id, userId);
  await unarchiveNotesByProjectId(id, userId);

  // Reinicia a contagem pro auto-arquivamento, mesma regra de task.service -
  // se o projeto ja tinha sido concluido, desarquivar recomeca o prazo
  // (projectArchiveDays) do zero.
  if (unarchived.completedAt) {
    return updateProjectCompletedAt(id, userId, new Date());
  }
  return unarchived;
}

export async function complete(id: string, userId: string) {
  const project = await completeProject(id, userId);
  if (!project) {
    throw new AppError(404, "Project not found");
  }
  return project;
}

// Roda periodicamente (ver server.ts). archive() ja cascateia pra
// tasks/notas do projeto.
export async function runAutoArchiveSweep() {
  const candidates = await findProjectsEligibleForAutoArchive();
  const now = Date.now();

  for (const project of candidates) {
    const completedAt = project.completedAt as Date;
    const thresholdMs = project.user.projectArchiveDays * 24 * 60 * 60 * 1000;
    if (now - completedAt.getTime() < thresholdMs) continue;

    await archive(project.id, project.userId);
    await createNotification({
      userId: project.userId,
      type: "project_archived",
      payload: { projectId: project.id, projectName: project.name },
    });
  }
}