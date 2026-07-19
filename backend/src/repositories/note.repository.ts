import { prisma } from "../utils/prisma.js";

async function findOwnedNote(id: string, userId: string) {
  return prisma.note.findFirst({ where: { id, userId } });
}

export async function createNote(
  userId: string,
  data: {
    title: string;
    content: string;
    tags?: string[];
    isPinned?: boolean;
    projectId?: string | null;
  }
) {
  return prisma.note.create({ data: { ...data, userId } });
}

export async function findNotesByUser(
  userId: string,
  filters: { projectId?: string | null; isDeleted?: boolean } = {}
) {
  return prisma.note.findMany({
    where: {
      userId,
      isDeleted: filters.isDeleted ?? false,
      ...(filters.projectId !== undefined ? { projectId: filters.projectId } : {}),
    },
    orderBy: { order: "asc" },
  });
}

export async function findNoteById(id: string, userId: string) {
  return findOwnedNote(id, userId);
}

export async function updateNote(
  id: string,
  userId: string,
  data: Partial<{
    title: string;
    content: string;
    tags: string[];
    isPinned: boolean;
    projectId: string | null;
  }>
) {
  const note = await findOwnedNote(id, userId);
  if (!note) return null;
  return prisma.note.update({ where: { id }, data });
}

export async function softDeleteNote(id: string, userId: string) {
  const note = await findOwnedNote(id, userId);
  if (!note) return null;
  return prisma.note.update({
    where: { id },
    data: { isDeleted: true, deletedAt: new Date() },
  });
}

export async function restoreNote(id: string, userId: string) {
  const note = await findOwnedNote(id, userId);
  if (!note) return null;
  return prisma.note.update({
    where: { id },
    data: { isDeleted: false, deletedAt: null },
  });
}

export async function permanentDeleteNote(id: string, userId: string) {
  const note = await findOwnedNote(id, userId);
  if (!note) return null;
  return prisma.note.delete({ where: { id } });
}

export async function permanentDeleteNotesByProjectId(projectId: string, userId: string) {
  return prisma.note.deleteMany({ where: { projectId, userId } });
}

export async function reorderNotes(userId: string, items: { id: string; order: number }[]) {
  return prisma.$transaction(
    items.map((item) =>
      prisma.note.updateMany({
        where: { id: item.id, userId },
        data: { order: item.order },
      })
    )
  );
}