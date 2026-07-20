import Fastify from "fastify";
import { errorHandler } from "./middlewares/error-handler.middleware.js";
import { authRoutes } from "./routes/auth.routes.js";
import { userRoutes } from "./routes/user.routes.js";
import { projectTypeRoutes } from "./routes/project-type.routes.js";
import { projectRoutes } from "./routes/project.routes.js";
import { taskRoutes } from "./routes/task.routes.js";
import { noteRoutes } from "./routes/note.routes.js";
import { focusSessionRoutes } from "./routes/focus-session.routes.js";

export function buildApp() {
  const app = Fastify({ logger: true });

  app.setErrorHandler(errorHandler);

  app.register(authRoutes);
  app.register(userRoutes);
  app.register(projectTypeRoutes);
  app.register(projectRoutes);
  app.register(taskRoutes);
  app.register(noteRoutes);
  app.register(focusSessionRoutes);

  return app;
}

async function start() {
  const app = buildApp();
  const port = Number(process.env["PORT"] ?? 3333);
  await app.listen({ port, host: "0.0.0.0" });
}

const isMainModule = import.meta.url === `file://${process.argv[1]}`;

if (isMainModule) {
  start().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
