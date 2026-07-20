import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as authController from "../controllers/auth.controller.js";

export async function authRoutes(app: FastifyInstance) {
  app.post("/auth/register", authController.register);
  app.post("/auth/login", authController.login);
  app.post("/auth/refresh", authController.refresh);
  app.post("/auth/logout", authController.logout);
  app.post("/auth/change-password", { preHandler: authMiddleware }, authController.changePassword);
}
