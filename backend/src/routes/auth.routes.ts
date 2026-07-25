import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as authController from "../controllers/auth.controller.js";

export async function authRoutes(app: FastifyInstance) {
  app.post("/auth/register", authController.register);
  app.post("/auth/login", authController.login);
  app.post("/auth/refresh", authController.refresh);
  app.post("/auth/logout", authController.logout);
  app.post("/auth/change-password", { preHandler: authMiddleware }, authController.changePassword);
  app.get("/auth/dev-mode", authController.devMode);
  app.get("/auth/google/authorize", authController.googleAuthorize);
  app.get("/auth/google/callback", authController.googleCallback);
  app.post("/auth/google/exchange", authController.googleExchange);
}
