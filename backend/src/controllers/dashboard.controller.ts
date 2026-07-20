import type { FastifyReply, FastifyRequest } from "fastify";
import * as dashboardService from "../services/dashboard.service.js";

export async function getStats(request: FastifyRequest, reply: FastifyReply) {
  const query = request.query as { days?: string };
  const days = query.days ? Number(query.days) : undefined;
  const windowDays = days !== undefined && !Number.isNaN(days) && days > 0 ? days : undefined;

  const stats = await dashboardService.getStats(request.user.id, windowDays);
  return reply.status(200).send(stats);
}
