import type { FastifyReply, FastifyRequest } from "fastify";
import * as notificationService from "../services/notification.service.js";
import { notificationResponseSchema } from "../schemas/notification.schema.js";
import { formatResponse } from "../utils/format-response.js";

const DEFAULT_LIMIT = 20;

export async function list(request: FastifyRequest, reply: FastifyReply) {
  const { limit } = request.query as { limit?: string };
  const parsedLimit = limit ? Number(limit) : DEFAULT_LIMIT;

  const result = await notificationService.list(request.user.id, parsedLimit);
  return reply.status(200).send({
    notifications: formatResponse(notificationResponseSchema, result.notifications),
    unreadCount: result.unreadCount,
  });
}

export async function markAllRead(request: FastifyRequest, reply: FastifyReply) {
  await notificationService.markAllRead(request.user.id);
  return reply.status(204).send();
}
