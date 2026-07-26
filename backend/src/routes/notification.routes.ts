import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as notificationController from "../controllers/notification.controller.js";

export async function notificationRoutes(app: FastifyInstance) {
  app.addHook("preHandler", authMiddleware);
  app.get("/notifications", notificationController.list);
  app.post("/notifications/read-all", notificationController.markAllRead);
}
