import type { FastifyReply, FastifyRequest } from "fastify";
import * as focusSessionService from "../services/focus-session.service.js";
import {
  completeFocusSessionSchema,
  createFocusSessionSchema,
  focusSessionResponseSchema,
  updateFocusSessionSchema,
} from "../schemas/focus-session.schema.js";
import { formatResponse } from "../utils/format-response.js";

export async function list(request: FastifyRequest, reply: FastifyReply) {
  const query = request.query as { taskId?: string };
  const sessions = await focusSessionService.list(request.user.id, { taskId: query.taskId });
  return reply.status(200).send(formatResponse(focusSessionResponseSchema, sessions));
}

export async function create(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = createFocusSessionSchema.validate(request.body);
  if (error) throw error;

  const session = await focusSessionService.create(request.user.id, value);
  return reply.status(201).send(formatResponse(focusSessionResponseSchema, session));
}

export async function update(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const { error, value } = updateFocusSessionSchema.validate(request.body);
  if (error) throw error;

  const session = await focusSessionService.update(id, request.user.id, value);
  return reply.status(200).send(formatResponse(focusSessionResponseSchema, session));
}

export async function complete(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const { error, value } = completeFocusSessionSchema.validate(request.body ?? {});
  if (error) throw error;

  const session = await focusSessionService.complete(id, request.user.id, value.completedAt);
  return reply.status(200).send(formatResponse(focusSessionResponseSchema, session));
}

export async function remove(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  await focusSessionService.remove(id, request.user.id);
  return reply.status(204).send();
}
