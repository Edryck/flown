import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as trashController from "../controllers/trash.controller.js";

export async function trashRoutes(app: FastifyInstance) {
  app.addHook("preHandler", authMiddleware);
  app.get("/trash", trashController.list);
  app.delete("/trash/empty", trashController.empty);
}
