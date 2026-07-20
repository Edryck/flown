import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as searchController from "../controllers/search.controller.js";

export async function searchRoutes(app: FastifyInstance) {
  app.addHook("preHandler", authMiddleware);
  app.get("/search", searchController.search);
}
