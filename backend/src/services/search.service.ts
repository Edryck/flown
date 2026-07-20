import { searchProjects } from "../repositories/project.repository.js";
import { searchTasks } from "../repositories/task.repository.js";
import { searchNotes } from "../repositories/note.repository.js";

export async function globalSearch(userId: string, query: string) {
  const [projects, tasks, notes] = await Promise.all([
    searchProjects(userId, query),
    searchTasks(userId, query),
    searchNotes(userId, query),
  ]);
  return { projects, tasks, notes };
}
