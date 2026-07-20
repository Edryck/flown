import type { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import * as focusSessionController from "../controllers/focus-session.controller.js";

export async function focusSessionRoutes(app: FastifyInstance) {
  app.addHook("preHandler", authMiddleware);
  app.get("/sessions", focusSessionController.list);
  app.post("/sessions", focusSessionController.create);
  app.patch("/sessions/:id", focusSessionController.update);
  app.post("/sessions/:id/complete", focusSessionController.complete);
  app.delete("/sessions/:id", focusSessionController.remove);
}
