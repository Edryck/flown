import type { FastifyReply, FastifyRequest } from "fastify";
import * as trashService from "../services/trash.service.js";
import { projectResponseSchema } from "../schemas/project.schema.js";
import { taskResponseSchema } from "../schemas/task.schema.js";
import { noteResponseSchema } from "../schemas/note.schema.js";
import { formatResponse } from "../utils/format-response.js";

export async function list(request: FastifyRequest, reply: FastifyReply) {
  const trash = await trashService.listTrash(request.user.id);
  return reply.status(200).send({
    projects: formatResponse(projectResponseSchema, trash.projects),
    tasks: formatResponse(taskResponseSchema, trash.tasks),
    notes: formatResponse(noteResponseSchema, trash.notes),
  });
}

export async function empty(request: FastifyRequest, reply: FastifyReply) {
  await trashService.emptyTrash(request.user.id);
  return reply.status(204).send();
}
