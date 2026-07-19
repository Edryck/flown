import type { FastifyReply, FastifyRequest } from "fastify";
import { verifyAccessToken } from "../utils/jwt.js";

declare module "fastify" {
  interface FastifyRequest {
    user: { id: string };
  }
}

export async function authMiddleware(request: FastifyRequest, reply: FastifyReply) {
  if (process.env["SKIP_AUTH"] === "true") {
    request.user = { id: process.env["DEV_USER_ID"] ?? "dev-user" };
    return;
  }

  const authHeader = request.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    return reply.status(401).send({ message: "Missing or invalid Authorization header" });
  }

  const token = authHeader.slice("Bearer ".length);

  try {
    const payload = verifyAccessToken(token);
    request.user = { id: payload.sub };
  } catch {
    return reply.status(401).send({ message: "Invalid or expired token" });
  }
}