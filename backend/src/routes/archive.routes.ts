import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as archiveController from "../controllers/archive.controller.js";

export async function archiveRoutes(app: FastifyInstance) {
  app.addHook("preHandler", authMiddleware);
  app.get("/archive", archiveController.list);
}
