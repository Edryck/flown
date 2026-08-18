import {
  countUnreadNotifications,
  deleteOldNotifications,
  findRecentNotifications,
  markAllNotificationsRead,
} from "../repositories/notification.repository.js";

// Notificacoes nao sao arquivadas, nunca - somem 7 dias depois de criadas,
// prazo fixo (nao configuravel, diferente dos intervalos de arquivamento de
// Task/Project). Roda periodicamente, ver server.ts.
const NOTIFICATION_RETENTION_DAYS = 7;

export async function list(userId: string, limit: number) {
  const [notifications, unreadCount] = await Promise.all([
    findRecentNotifications(userId, limit),
    countUnreadNotifications(userId),
  ]);
  return { notifications, unreadCount };
}

export async function markAllRead(userId: string) {
  await markAllNotificationsRead(userId);
}

export async function pruneExpiredNotifications() {
  const cutoff = new Date(Date.now() - NOTIFICATION_RETENTION_DAYS * 24 * 60 * 60 * 1000);
  await deleteOldNotifications(cutoff);
}
