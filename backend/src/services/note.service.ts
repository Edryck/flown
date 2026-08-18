import { AppError } from "../utils/errors.js";
import {
  archiveNote,
  createNote,
  findNoteById,
  findNotesByUser,
  permanentDeleteNote,
  reorderNotes,
  restoreNote,
  softDeleteNote,
  unarchiveNote,
  updateNote,
} from "../repositories/note.repository.js";
import { findProjectById } from "../repositories/project.repository.js";

type NoteInput = {
  title: string;
  content: string;
  color?: string;
  tags?: string[];
  isPinned?: boolean;
  projectId?: string | null;
};

export async function create(userId: string, data: NoteInput) {
  return createNote(userId, data);
}

export async function list(
  userId: string,
  filters: {
    projectId?: string | null;
    isDeleted?: boolean;
    isArchived?: boolean;
    search?: string;
    tag?: string;
  } = {}
) {
  const { tag, ...repositoryFilters } = filters;
  const notes = await findNotesByUser(userId, repositoryFilters);
  if (!tag) return notes;
  return notes.filter((note) => (note.tags as string[]).includes(tag));
}

export async function getById(id: string, userId: string) {
  const note = await findNoteById(id, userId);
  if (!note) {
    throw new AppError(404, "Note not found");
  }
  return note;
}

export async function update(id: string, userId: string, data: Partial<NoteInput>) {
  const note = await updateNote(id, userId, data);
  if (!note) {
    throw new AppError(404, "Note not found");
  }
  return note;
}

export async function softDelete(id: string, userId: string) {
  const note = await softDeleteNote(id, userId);
  if (!note) {
    throw new AppError(404, "Note not found");
  }
  return note;
}

export async function restore(id: string, userId: string) {
  const note = await restoreNote(id, userId);
  if (!note) {
    throw new AppError(404, "Note not found");
  }
  return note;
}

export async function permanentDelete(id: string, userId: string) {
  const note = await permanentDeleteNote(id, userId);
  if (!note) {
    throw new AppError(404, "Note not found");
  }
}

export async function archive(id: string, userId: string) {
  const note = await archiveNote(id, userId);
  if (!note) {
    throw new AppError(404, "Note not found");
  }
  return note;
}

export async function unarchive(id: string, userId: string) {
  const note = await findNoteById(id, userId);
  if (!note) {
    throw new AppError(404, "Note not found");
  }
  // Nota presa a um projeto arquivado so pode voltar via o projeto - o
  // isArchived dela e derivado do projeto nesse caso (ver project.service.ts
  // archive/unarchive cascateando pra notesByProjectId).
  if (note.projectId) {
    const project = await findProjectById(note.projectId, userId);
    if (project?.isArchived) {
      throw new AppError(400, "Note belongs to an archived project");
    }
  }
  const unarchived = await unarchiveNote(id, userId);
  if (!unarchived) {
    throw new AppError(404, "Note not found");
  }
  return unarchived;
}

export async function reorder(userId: string, items: { id: string; order: number }[]) {
  await reorderNotes(userId, items);
}