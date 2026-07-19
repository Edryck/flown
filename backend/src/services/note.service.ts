import { AppError } from "../utils/errors.js";
import {
  createNote,
  findNoteById,
  findNotesByUser,
  permanentDeleteNote,
  reorderNotes,
  restoreNote,
  softDeleteNote,
  updateNote,
} from "../repositories/note.repository.js";

type NoteInput = {
  title: string;
  content: string;
  tags?: string[];
  isPinned?: boolean;
  projectId?: string | null;
};

export async function create(userId: string, data: NoteInput) {
  return createNote(userId, data);
}

export async function list(userId: string, filters: { projectId?: string | null; isDeleted?: boolean } = {}) {
  return findNotesByUser(userId, filters);
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

export async function reorder(userId: string, items: { id: string; order: number }[]) {
  await reorderNotes(userId, items);
}