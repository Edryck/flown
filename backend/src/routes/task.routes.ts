import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as taskController from "../controllers/task.controller.js";

export async function taskRoutes(app: FastifyInstance) {
  app.addHook("preHandler", authMiddleware);
  app.get("/tasks", taskController.list);
  app.post("/tasks", taskController.create);
  app.patch("/tasks/reorder", taskController.reorder);
  app.get("/tasks/:id", taskController.getById);
  app.patch("/tasks/:id", taskController.update);
  app.delete("/tasks/:id", taskController.softDelete);
  app.post("/tasks/:id/restore", taskController.restore);
  app.delete("/tasks/:id/permanent", taskController.permanentDelete);
  app.patch("/tasks/:id/archive", taskController.archive);
  app.patch("/tasks/:id/unarchive", taskController.unarchive);
  app.get("/tasks/:id/subtasks", taskController.listSubtasks);
  app.post("/tasks/:id/subtasks", taskController.createSubtask);
}
