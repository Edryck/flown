import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as projectController from "../controllers/project.controller.js";

export async function projectRoutes(app: FastifyInstance) {
  app.addHook("preHandler", authMiddleware);
  app.get("/projects", projectController.list);
  app.post("/projects", projectController.create);
  app.get("/projects/:id", projectController.getById);
  app.patch("/projects/:id", projectController.update);
  app.delete("/projects/:id", projectController.softDelete);
  app.post("/projects/:id/restore", projectController.restore);
  app.delete("/projects/:id/permanent", projectController.permanentDelete);
  app.patch("/projects/:id/archive", projectController.archive);
  app.patch("/projects/:id/unarchive", projectController.unarchive);
  app.get("/projects/:id/tasks", projectController.listTasks);
  app.get("/projects/:id/notes", projectController.listNotes);
}
