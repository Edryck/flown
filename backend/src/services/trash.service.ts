import { findProjectsByUser } from "../repositories/project.repository.js";
import { findTaskById, findTasksByUser } from "../repositories/task.repository.js";
import { findNoteById, findNotesByUser } from "../repositories/note.repository.js";
import * as projectService from "./project.service.js";
import * as taskService from "./task.service.js";
import * as noteService from "./note.service.js";

export async function listTrash(userId: string) {
  const [projects, tasks, notes] = await Promise.all([
    findProjectsByUser(userId, { isDeleted: true }),
    findTasksByUser(userId, { isDeleted: true }),
    findNotesByUser(userId, { isDeleted: true }),
  ]);
  return { projects, tasks, notes };
}

export async function emptyTrash(userId: string) {
  // Apaga projetos primeiro — permanentDelete de Project ja cascateia pras
  // tasks/notas dele (log 07), entao boa parte do trabalho de tasks/notas
  // trashadas dentro de um projeto trashado acontece aqui.
  const trashedProjects = await findProjectsByUser(userId, { isDeleted: true });
  for (const project of trashedProjects) {
    await projectService.permanentDelete(project.id, userId);
  }

  // Re-consulta depois da cascata acima — o que sobrar sao tasks/notas
  // trashadas que nao tinham projeto, ou cujo projeto nao estava trashado.
  const trashedTasks = await findTasksByUser(userId, { isDeleted: true });
  const trashedTaskIds = new Set(trashedTasks.map((task) => task.id));
  for (const task of trashedTasks) {
    // Se o pai tambem esta na lixeira, o permanentDelete dele ja vai levar
    // essa subtask junto (parentTaskId usa onDelete: NoAction — log 02/07) —
    // processar a subtask aqui de novo geraria 404 por ja nao existir mais.
    const parentAlsoTrashed = task.parentTaskId !== null && trashedTaskIds.has(task.parentTaskId);
    if (parentAlsoTrashed) continue;

    const stillExists = await findTaskById(task.id, userId);
    if (!stillExists) continue;
    await taskService.permanentDelete(task.id, userId);
  }

  const trashedNotes = await findNotesByUser(userId, { isDeleted: true });
  for (const note of trashedNotes) {
    const stillExists = await findNoteById(note.id, userId);
    if (!stillExists) continue;
    await noteService.permanentDelete(note.id, userId);
  }
}
