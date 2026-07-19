import { prisma } from "../src/utils/prisma.js";

const projectTypes = [
  {
    name: "software",
    availableStatus: ["Backlog", "Todo", "In Progress", "In Review", "Blocked", "Done", "Cancelled"],
  },
  {
    name: "general",
    availableStatus: ["Todo", "In Progress", "Blocked", "Done", "Cancelled"],
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