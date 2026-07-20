import type { FastifyReply, FastifyRequest } from "fastify";
import * as authService from "../services/auth.service.js";
import {
  authResponseSchema,
  changePasswordSchema,
  loginSchema,
  refreshResponseSchema,
  refreshSchema,
  registerSchema,
} from "../schemas/auth.schema.js";
import { formatResponse } from "../utils/format-response.js";

export async function register(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = registerSchema.validate(request.body);
  if (error) throw error;

  const result = await authService.register(value);
  return reply.status(201).send(formatResponse(authResponseSchema, result));
}

export async function login(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = loginSchema.validate(request.body);
  if (error) throw error;

  const result = await authService.login(value);
  return reply.status(200).send(formatResponse(authResponseSchema, result));
}

export async function refresh(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = refreshSchema.validate(request.body);
  if (error) throw error;

  const result = await authService.refresh(value.refreshToken);
  return reply.status(200).send(formatResponse(refreshResponseSchema, result));
}

export async function logout(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = refreshSchema.validate(request.body);
  if (error) throw error;

  await authService.logout(value.refreshToken);
  return reply.status(204).send();
}

export async function changePassword(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = changePasswordSchema.validate(request.body);
  if (error) throw error;

  await authService.changePassword(request.user.id, value);
  return reply.status(204).send();
}
