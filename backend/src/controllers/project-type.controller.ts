import type { FastifyReply, FastifyRequest } from "fastify";
import * as projectTypeService from "../services/project-type.service.js";
import { createProjectTypeSchema, projectTypeResponseSchema } from "../schemas/project-type.schema.js";
import { formatResponse } from "../utils/format-response.js";

export async function list(_request: FastifyRequest, reply: FastifyReply) {
  const types = await projectTypeService.list();
  return reply.status(200).send(formatResponse(projectTypeResponseSchema, types));
}

export async function create(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = createProjectTypeSchema.validate(request.body);
  if (error) throw error;

  const type = await projectTypeService.create(value);
  return reply.status(201).send(formatResponse(projectTypeResponseSchema, type));
}
