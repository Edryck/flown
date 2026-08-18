import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as noteController from "../controllers/note.controller.js";

export async function noteRoutes(app: FastifyInstance) {
  app.addHook("preHandler", authMiddleware);
  app.get("/notes", noteController.list);
  app.post("/notes", noteController.create);
  app.patch("/notes/reorder", noteController.reorder);
  app.get("/notes/:id", noteController.getById);
  app.patch("/notes/:id", noteController.update);
  app.delete("/notes/:id", noteController.softDelete);
  app.post("/notes/:id/restore", noteController.restore);
  app.delete("/notes/:id/permanent", noteController.permanentDelete);
  app.patch("/notes/:id/archive", noteController.archive);
  app.patch("/notes/:id/unarchive", noteController.unarchive);
}
