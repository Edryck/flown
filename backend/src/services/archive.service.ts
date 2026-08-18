import { findProjectsByUser } from "../repositories/project.repository.js";
import { findTasksByUser } from "../repositories/task.repository.js";
import { findNotesByUser } from "../repositories/note.repository.js";

export async function listArchive(userId: string) {
  const [projects, tasks, notes] = await Promise.all([
    findProjectsByUser(userId, { isArchived: true }),
    findTasksByUser(userId, { isArchived: true }),
    findNotesByUser(userId, { isArchived: true }),
  ]);
  return { projects, tasks, notes };
}
