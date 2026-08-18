import bcrypt from "bcrypt";
import { prisma } from "../src/utils/prisma.js";

const DEV_USER_ID = "dev-user";

// "Backlog"/"Blocked"/"Cancelled" removidos (decisão do usuário): não faziam
// sentido como colunas do Kanban - "Blocked" nunca era usado na prática, e
// "Cancelled" foi substituído pelo fluxo de arquivamento (ainda não
// implementado) em vez de um status dedicado. Confirmado 0 tasks com esses
// status no banco antes da mudança - update seguro via upsert, sem precisar
// migrar dado nenhum.
const projectTypes = [
  {
    name: "software",
    availableStatus: ["Todo", "In Progress", "In Review", "Done"],
  },
  {
    name: "general",
    availableStatus: ["Todo", "In Progress", "Done"],
  },
];

async function main() {
  for (const type of projectTypes) {
    await prisma.projectType.upsert({
      where: { name: type.name },
      update: { availableStatus: type.availableStatus },
      create: type,
    });
  }
  // Usuario fixo usado pelo bypass de dev do frontend (AuthController.devBypass,
  // so aparece com SKIP_AUTH=true) — nunca loga de verdade, mas precisa existir
  // como User real pra FK de Task/Project/Note/FocusSession nao quebrar.
  const devPasswordHash = await bcrypt.hash("dev-only-not-a-real-password", 10);
  await prisma.user.upsert({
    where: { id: DEV_USER_ID },
    update: {},
    create: {
      id: DEV_USER_ID,
      name: "Dev User",
      email: "dev@flown.local",
      password: devPasswordHash,
    },
  });

  console.log("Seed completed.");
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });