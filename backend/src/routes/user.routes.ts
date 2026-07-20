import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as userController from "../controllers/user.controller.js";

export async function userRoutes(app: FastifyInstance) {
  app.addHook("preHandler", authMiddleware);
  app.get("/users/me", userController.getMe);
  app.patch("/users/me", userController.updateMe);
}
