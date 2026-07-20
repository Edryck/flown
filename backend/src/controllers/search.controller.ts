import type { FastifyReply, FastifyRequest } from "fastify";
import * as searchService from "../services/search.service.js";
import { projectResponseSchema } from "../schemas/project.schema.js";
import { taskResponseSchema } from "../schemas/task.schema.js";
import { noteResponseSchema } from "../schemas/note.schema.js";
import { formatResponse } from "../utils/format-response.js";
import { AppError } from "../utils/errors.js";

export async function search(request: FastifyRequest, reply: FastifyReply) {
  const { q } = request.query as { q?: string };
  const query = q?.trim();
  if (!query) {
    throw new AppError(400, 'Query param "q" is required');
  }

  const result = await searchService.globalSearch(request.user.id, query);
  return reply.status(200).send({
    projects: formatResponse(projectResponseSchema, result.projects),
    tasks: formatResponse(taskResponseSchema, result.tasks),
    notes: formatResponse(noteResponseSchema, result.notes),
  });
}
