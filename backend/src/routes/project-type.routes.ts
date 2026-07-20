import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as projectTypeController from "../controllers/project-type.controller.js";

export async function projectTypeRoutes(app: FastifyInstance) {
  app.get("/project-types", projectTypeController.list);
  app.post("/project-types", { preHandler: authMiddleware }, projectTypeController.create);
}
