import type { FastifyError, FastifyReply, FastifyRequest } from "fastify";
import { AppError } from "../utils/errors.js";

export function errorHandler(error: FastifyError | Error, request: FastifyRequest, reply: FastifyReply) {
  if (error instanceof AppError) {
    return reply.status(error.statusCode).send({ message: error.message });
  }

  if ("isJoi" in error && error.isJoi) {
    return reply.status(400).send({ message: error.message });
  }

  request.log.error(error);
  return reply.status(500).send({ message: "Internal server error" });
}