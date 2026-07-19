import { AppError } from "../utils/errors.js";
import { findProjectTypeById } from "../repositories/project-type.repository.js";
import {
  archiveProject,
  createProject,
  findProjectById,
  findProjectsByUser,
  permanentDeleteProject,
  restoreProject,
  softDeleteProject,
  unarchiveProject,
  updateProject,
} from "../repositories/project.repository.js";
import { permanentDeleteTasksByProjectId } from "../repositories/task.repository.js";
import { permanentDeleteNotesByProjectId } from "../repositories/note.repository.js";

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

export async function list(userId: string, filters: { isDeleted?: boolean; isArchived?: boolean } = {}) {
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
  return project;
}

export async function unarchive(id: string, userId: string) {
  const project = await unarchiveProject(id, userId);
  if (!project) {
    throw new AppError(404, "Project not found");
  }
  return project;
}