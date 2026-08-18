import { prisma } from "../utils/prisma.js";

async function findOwnedProject(id: string, userId: string) {
  return prisma.project.findFirst({ where: { id, userId } });
}

export async function createProject(
  userId: string,
  data: { name: string; description?: string | null; color: string; typeId: string }
) {
  return prisma.project.create({ data: { ...data, userId } });
}

export async function findProjectsByUser(
  userId: string,
  filters: { isDeleted?: boolean; isArchived?: boolean; search?: string } = {}
) {
  return prisma.project.findMany({
    where: {
      userId,
      isDeleted: filters.isDeleted ?? false,
      isArchived: filters.isArchived ?? false,
      ...(filters.search
        ? { OR: [{ name: { contains: filters.search } }, { description: { contains: filters.search } }] }
        : {}),
    },
    orderBy: { order: "asc" },
  });
}

export async function searchProjects(userId: string, query: string) {
  return prisma.project.findMany({
    where: {
      userId,
      isDeleted: false,
      OR: [{ name: { contains: query } }, { description: { contains: query } }],
    },
    orderBy: { updatedAt: "desc" },
  });
}

export async function findProjectById(id: string, userId: string) {
  return findOwnedProject(id, userId);
}

export async function updateProject(
  id: string,
  userId: string,
  data: { name?: string; description?: string | null; color?: string; typeId?: string }
) {
  const project = await findOwnedProject(id, userId);
  if (!project) return null;
  return prisma.project.update({ where: { id }, data });
}

export async function softDeleteProject(id: string, userId: string) {
  const project = await findOwnedProject(id, userId);
  if (!project) return null;
  return prisma.project.update({
    where: { id },
    data: { isDeleted: true, deletedAt: new Date() },
  });
}

export async function restoreProject(id: string, userId: string) {
  const project = await findOwnedProject(id, userId);
  if (!project) return null;
  return prisma.project.update({
    where: { id },
    data: { isDeleted: false, deletedAt: null },
  });
}

export async function permanentDeleteProject(id: string, userId: string) {
  const project = await findOwnedProject(id, userId);
  if (!project) return null;
  return prisma.project.delete({ where: { id } });
}

export async function archiveProject(id: string, userId: string) {
  const project = await findOwnedProject(id, userId);
  if (!project) return null;
  return prisma.project.update({
    where: { id },
    data: { isArchived: true, archivedAt: new Date() },
  });
}

export async function unarchiveProject(id: string, userId: string) {
  const project = await findOwnedProject(id, userId);
  if (!project) return null;
  return prisma.project.update({
    where: { id },
    data: { isArchived: false, archivedAt: null },
  });
}

export async function completeProject(id: string, userId: string) {
  const project = await findOwnedProject(id, userId);
  if (!project) return null;
  return prisma.project.update({ where: { id }, data: { completedAt: new Date() } });
}

export async function updateProjectCompletedAt(id: string, userId: string, completedAt: Date | null) {
  const project = await findOwnedProject(id, userId);
  if (!project) return null;
  return prisma.project.update({ where: { id }, data: { completedAt } });
}

// Sem `userId`, mesmo padrao de findTasksApproachingDue/
// findTasksEligibleForAutoArchive - roda num job periodico varrendo todo
// mundo. O corte de dias e por usuario (`user.projectArchiveDays`), a
// comparacao final acontece em memoria no service.
export async function findProjectsEligibleForAutoArchive() {
  return prisma.project.findMany({
    where: {
      isDeleted: false,
      isArchived: false,
      completedAt: { not: null },
    },
    include: { user: { select: { id: true, projectArchiveDays: true } } },
  });
}
