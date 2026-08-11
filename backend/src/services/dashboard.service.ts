import { findAllActiveTasksSnapshot, findTasksForDashboardWindow } from "../repositories/task.repository.js";
import { findCompletedSessionsSince, sumFocusDurationByUser } from "../repositories/focus-session.repository.js";
import { COMPLETED_STATUS } from "./task.service.js";

const DEFAULT_WINDOW_DAYS = 90;
const STREAK_LOOKBACK_DAYS = 400;

type WindowTask = {
  status: string;
  priority: string;
  createdAt: Date;
  completedAt: Date | null;
  dueDate: Date | null;
};

type SnapshotTask = {
  status: string;
  priority: string;
  dueDate: Date | null;
  completedAt: Date | null;
};

function toDateKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function daysAgo(days: number): Date {
  const date = new Date();
  date.setDate(date.getDate() - days);
  date.setHours(0, 0, 0, 0);
  return date;
}

function buildHeatmap(tasks: WindowTask[], since: Date) {
  const counts = new Map<string, number>();
  for (const task of tasks) {
    if (task.status !== COMPLETED_STATUS || !task.completedAt || task.completedAt < since) continue;
    const key = toDateKey(task.completedAt);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return Array.from(counts.entries())
    .map(([date, count]) => ({ date, count }))
    .sort((a, b) => a.date.localeCompare(b.date));
}

function buildCompletionRate(tasks: WindowTask[], since: Date) {
  const created = tasks.filter((task) => task.createdAt >= since).length;
  const completed = tasks.filter(
    (task) => task.status === COMPLETED_STATUS && task.completedAt && task.completedAt >= since
  ).length;
  return { created, completed, rate: created > 0 ? completed / created : 0 };
}

function buildAverageTimeToCompleteByPriority(tasks: WindowTask[]) {
  const byPriority = new Map<string, number[]>();
  for (const task of tasks) {
    if (task.status !== COMPLETED_STATUS || !task.completedAt) continue;
    const hours = (task.completedAt.getTime() - task.createdAt.getTime()) / (1000 * 60 * 60);
    const list = byPriority.get(task.priority) ?? [];
    list.push(hours);
    byPriority.set(task.priority, list);
  }
  const result: Record<string, number | null> = {};
  for (const priority of ["Low", "Medium", "High"]) {
    const list = byPriority.get(priority);
    result[priority] = list && list.length > 0 ? list.reduce((a, b) => a + b, 0) / list.length : null;
  }
  return result;
}

function buildStreak(sessions: { completedAt: Date | null }[]) {
  const productiveDays = new Set(
    sessions.filter((session) => session.completedAt).map((session) => toDateKey(session.completedAt as Date))
  );
  let streak = 0;
  const cursor = new Date();
  cursor.setHours(0, 0, 0, 0);
  while (productiveDays.has(toDateKey(cursor))) {
    streak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

function buildFocusToday(sum: { _sum: { durationSeconds: number | null }; _count: number }) {
  const todaySeconds = sum._sum.durationSeconds ?? 0;
  const todaySessionCount = sum._count;
  return {
    todaySeconds,
    todaySessionCount,
    averageSessionSeconds: todaySessionCount > 0 ? todaySeconds / todaySessionCount : 0,
  };
}

function buildPeakHour(tasks: WindowTask[]) {
  const histogram = new Array(24).fill(0);
  for (const task of tasks) {
    if (task.status !== COMPLETED_STATUS || !task.completedAt) continue;
    histogram[task.completedAt.getHours()] += 1;
  }
  const hasData = histogram.some((count) => count > 0);
  return { histogram, peakHour: hasData ? histogram.indexOf(Math.max(...histogram)) : null };
}

function buildDueStatus(tasks: SnapshotTask[]) {
  const now = new Date();
  let overdue = 0;
  let onTrack = 0;
  let completedOnTime = 0;
  let completedLate = 0;
  for (const task of tasks) {
    if (!task.dueDate) continue;
    if (task.status === COMPLETED_STATUS) {
      if (task.completedAt && task.completedAt <= task.dueDate) completedOnTime += 1;
      else completedLate += 1;
    } else if (task.dueDate < now) {
      overdue += 1;
    } else {
      onTrack += 1;
    }
  }
  return { overdue, onTrack, completedOnTime, completedLate };
}

function buildDistribution(tasks: SnapshotTask[]) {
  const byStatus = new Map<string, number>();
  const byPriority = new Map<string, number>();
  for (const task of tasks) {
    byStatus.set(task.status, (byStatus.get(task.status) ?? 0) + 1);
    byPriority.set(task.priority, (byPriority.get(task.priority) ?? 0) + 1);
  }
  return { byStatus: Object.fromEntries(byStatus), byPriority: Object.fromEntries(byPriority) };
}

export async function getStats(userId: string, windowDays: number = DEFAULT_WINDOW_DAYS) {
  const since = daysAgo(windowDays);
  const [windowTasks, allTasks, sessions, todayFocusSum] = await Promise.all([
    findTasksForDashboardWindow(userId, since),
    findAllActiveTasksSnapshot(userId),
    findCompletedSessionsSince(userId, daysAgo(STREAK_LOOKBACK_DAYS)),
    sumFocusDurationByUser(userId, daysAgo(0)),
  ]);

  return {
    windowDays,
    productivity: {
      heatmap: buildHeatmap(windowTasks, since),
      completionRate: buildCompletionRate(windowTasks, since),
      averageTimeToCompleteByPriority: buildAverageTimeToCompleteByPriority(windowTasks),
    },
    focus: {
      streak: buildStreak(sessions),
      peakHour: buildPeakHour(windowTasks),
      ...buildFocusToday(todayFocusSum),
    },
    projectHealth: {
      dueStatus: buildDueStatus(allTasks),
      distribution: buildDistribution(allTasks),
    },
  };
}
