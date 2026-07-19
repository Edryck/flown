import { prisma } from "../utils/prisma.js";

export async function createProjectType(data: { name: string; availableStatus: string[] }) {
  return prisma.projectType.create({ data });
}

export async function findAllProjectTypes() {
  return prisma.projectType.findMany();
}

export async function findProjectTypeById(id: string) {
  return prisma.projectType.findUnique({ where: { id } });
}

export async function findProjectTypeByName(name: string) {
  return prisma.projectType.findUnique({ where: { name } });
}
