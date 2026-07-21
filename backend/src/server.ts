import { pathToFileURL } from "node:url";
import Fastify from "fastify";
import { errorHandler } from "./middlewares/error-handler.middleware.js";
import { authRoutes } from "./routes/auth.routes.js";
import { userRoutes } from "./routes/user.routes.js";
import { projectTypeRoutes } from "./routes/project-type.routes.js";
import { projectRoutes } from "./routes/project.routes.js";
import { taskRoutes } from "./routes/task.routes.js";
import { noteRoutes } from "./routes/note.routes.js";
import { focusSessionRoutes } from "./routes/focus-session.routes.js";
import { dashboardRoutes } from "./routes/dashboard.routes.js";
import { searchRoutes } from "./routes/search.routes.js";
import { trashRoutes } from "./routes/trash.routes.js";

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
  app.register(dashboardRoutes);
  app.register(searchRoutes);
  app.register(trashRoutes);

  return app;
}

async function start() {
  const app = buildApp();
  const port = Number(process.env["PORT"] ?? 3333);
  await app.listen({ port, host: "0.0.0.0" });
}

// process.argv[1] vem com barra invertida no Windows (D:\...), sem prefixo
// file:// — comparar como string ingenua com import.meta.url (que sempre
// normaliza pra file:///D:/...) falha silenciosamente la. pathToFileURL
// converte o path do jeito certo pro SO atual antes de comparar.
const isMainModule =
  process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isMainModule) {
  start().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
