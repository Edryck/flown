import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as dashboardController from "../controllers/dashboard.controller.js";

export async function dashboardRoutes(app: FastifyInstance) {
  app.addHook("preHandler", authMiddleware);
  app.get("/dashboard/stats", dashboardController.getStats);
}
