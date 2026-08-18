import { prisma } from "../utils/prisma.js";

export async function createNotification(data: {
  userId: string;
  type: string;
  payload: unknown;
  taskId?: string | null;
}) {
  return prisma.notification.create({
    data: {
      userId: data.userId,
      type: data.type,
      payload: data.payload as object,
      taskId: data.taskId ?? null,
    },
  });
}

export async function findRecentNotifications(userId: string, limit: number) {
  return prisma.notification.findMany({
    where: { userId },
    orderBy: { createdAt: "desc" },
    take: limit,
  });
}

export async function countUnreadNotifications(userId: string) {
  return prisma.notification.count({ where: { userId, isRead: false } });
}

export async function markAllNotificationsRead(userId: string) {
  return prisma.notification.updateMany({ where: { userId, isRead: false }, data: { isRead: true } });
}

// Usado pra decidir se um resumo de produtividade (semanal/mensal) ja foi
// gerado no periodo atual - filtra em memoria (nao no banco) o campo
// `period` dentro do JSON, pra nao depender de filtro de JSON path do
// Prisma/SQLite (suporte variavel entre providers).
export async function findRecentProductivitySummaries(userId: string, since: Date) {
  return prisma.notification.findMany({
    where: { userId, type: "productivity_summary", createdAt: { gte: since } },
    select: { payload: true },
  });
}

// Sem `userId` - roda num job periodico varrendo todo mundo. Notificacoes
// nunca sao arquivadas, so somem (hard delete) depois de um prazo fixo.
export async function deleteOldNotifications(cutoff: Date) {
  return prisma.notification.deleteMany({ where: { createdAt: { lt: cutoff } } });
}
