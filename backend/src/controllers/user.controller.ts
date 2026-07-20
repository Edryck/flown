import type { FastifyReply, FastifyRequest } from "fastify";
import * as userService from "../services/user.service.js";
import { updateUserSchema, userResponseSchema } from "../schemas/user.schema.js";
import { formatResponse } from "../utils/format-response.js";

export async function getMe(request: FastifyRequest, reply: FastifyReply) {
  const user = await userService.getById(request.user.id);
  return reply.status(200).send(formatResponse(userResponseSchema, user));
}

export async function updateMe(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = updateUserSchema.validate(request.body);
  if (error) throw error;

  const user = await userService.updateProfile(request.user.id, value);
  return reply.status(200).send(formatResponse(userResponseSchema, user));
}
