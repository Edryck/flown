import { prisma } from "../utils/prisma.js";

async function findOwnedNote(id: string, userId: string) {
  return prisma.note.findFirst({ where: { id, userId } });
}

export async function createNote(
  userId: string,
  data: {
    title: string;
    content: string;
    color?: string;
    tags?: string[];
    isPinned?: boolean;
    projectId?: string | null;
  }
) {
  return prisma.note.create({ data: { ...data, userId } });
}

export async function findNotesByUser(
  userId: string,
  filters: { projectId?: string | null; isDeleted?: boolean; isArchived?: boolean; search?: string } = {}
) {
  return prisma.note.findMany({
    where: {
      userId,
      isDeleted: filters.isDeleted ?? false,
      isArchived: filters.isArchived ?? false,
      ...(filters.projectId !== undefined ? { projectId: filters.projectId } : {}),
      ...(filters.search
        ? { OR: [{ title: { contains: filters.search } }, { content: { contains: filters.search } }] }
        : {}),
    },
    orderBy: { order: "asc" },
  });
}

export async function searchNotes(userId: string, query: string) {
  // Mesmo motivo de `searchTasks` em `task.repository.ts`: `tags` é Json no
  // SQLite, sem filtro de substring suportado pelo Prisma nesse provider —
  // filtra em memória.
  const notes = await prisma.note.findMany({
    where: { userId, isDeleted: false },
    orderBy: { updatedAt: "desc" },
  });
  const q = query.toLowerCase();
  return notes.filter((note) => {
    const tags = Array.isArray(note.tags) ? (note.tags as string[]) : [];
    return (
      note.title.toLowerCase().includes(q) ||
      note.content.toLowerCase().includes(q) ||
      tags.some((tag) => tag.toLowerCase().includes(q))
    );
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
    color: string;
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

export async function softDeleteNotesByProjectId(projectId: string, userId: string) {
  return prisma.note.updateMany({
    where: { projectId, userId, isDeleted: false },
    data: { isDeleted: true, deletedAt: new Date() },
  });
}

export async function archiveNote(id: string, userId: string) {
  const note = await findOwnedNote(id, userId);
  if (!note) return null;
  return prisma.note.update({
    where: { id },
    data: { isArchived: true, archivedAt: new Date() },
  });
}

export async function unarchiveNote(id: string, userId: string) {
  const note = await findOwnedNote(id, userId);
  if (!note) return null;
  return prisma.note.update({
    where: { id },
    data: { isArchived: false, archivedAt: null },
  });
}

export async function archiveNotesByProjectId(projectId: string, userId: string) {
  return prisma.note.updateMany({
    where: { projectId, userId, isDeleted: false },
    data: { isArchived: true, archivedAt: new Date() },
  });
}

export async function unarchiveNotesByProjectId(projectId: string, userId: string) {
  return prisma.note.updateMany({
    where: { projectId, userId, isDeleted: false },
    data: { isArchived: false, archivedAt: null },
  });
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