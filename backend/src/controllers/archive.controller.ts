import type { FastifyReply, FastifyRequest } from "fastify";
import * as archiveService from "../services/archive.service.js";
import { projectResponseSchema } from "../schemas/project.schema.js";
import { taskResponseSchema } from "../schemas/task.schema.js";
import { noteResponseSchema } from "../schemas/note.schema.js";
import { formatResponse } from "../utils/format-response.js";

export async function list(request: FastifyRequest, reply: FastifyReply) {
  const archive = await archiveService.listArchive(request.user.id);
  return reply.status(200).send({
    projects: formatResponse(projectResponseSchema, archive.projects),
    tasks: formatResponse(taskResponseSchema, archive.tasks),
    notes: formatResponse(noteResponseSchema, archive.notes),
  });
}
