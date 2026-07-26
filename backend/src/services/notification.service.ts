import {
  countUnreadNotifications,
  findRecentNotifications,
  markAllNotificationsRead,
} from "../repositories/notification.repository.js";

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
