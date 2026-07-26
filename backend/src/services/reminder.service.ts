import { findTasksApproachingDue, updateTaskRemindersSent } from "../repositories/task.repository.js";
import { createNotification } from "../repositories/notification.repository.js";
import { sendEmail } from "../utils/mailer.js";

// Estagios de aviso antes do prazo, do menos ao mais urgente. O maior
// (24h) define a janela da query no banco - o service decide, task por
// task, qual estagio menor ja foi cruzado.
const THRESHOLD_HOURS = [24, 12, 6, 1] as const;
const MAX_WINDOW_HOURS = Math.max(...THRESHOLD_HOURS);

function escapeHtml(value: string): string {
  const replacements: Record<string, string> = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  };
  return value.replace(/[&<>"']/g, (char) => replacements[char]!);
}

function formatDueDate(date: Date): string {
  return date.toLocaleString("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function formatThreshold(hours: number): string {
  return hours === 1 ? "1 hora" : `${hours} horas`;
}

type ReminderTask = { title: string; dueDate: Date; projectName: string | null; thresholdHours: number };

// HTML "de mao" (sem template engine) de proposito - e um unico e-mail
// simples, cores batendo com o gradiente/paleta usados na tela de login do
// Flutter (login_screen.dart), pra nao parecer um e-mail de outro produto.
function buildReminderEmailHtml(userName: string, tasks: ReminderTask[]): string {
  const rows = tasks
    .map(
      (task) => `
        <tr>
          <td style="padding:12px 16px;border-bottom:1px solid #EDEDED;">
            <div style="font-weight:600;color:#1A202C;font-size:14px;">${escapeHtml(task.title)}</div>
            ${task.projectName ? `<div style="color:#6B7B8F;font-size:12px;margin-top:2px;">${escapeHtml(task.projectName)}</div>` : ""}
            <div style="color:#B2560D;font-size:12px;margin-top:2px;">Faltam ${formatThreshold(task.thresholdHours)}</div>
          </td>
          <td style="padding:12px 16px;border-bottom:1px solid #EDEDED;text-align:right;color:#D97373;font-size:13px;font-weight:500;white-space:nowrap;">
            ${formatDueDate(task.dueDate)}
          </td>
        </tr>`
    )
    .join("");

  return `
<!doctype html>
<html lang="pt-BR">
<body style="margin:0;padding:0;background:#F3F6F9;font-family:-apple-system,'Segoe UI',Roboto,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width:480px;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #DDE4EC;">
          <tr>
            <td style="background:linear-gradient(135deg,#D4EEEC 0%,#E8F1F8 50%,#EBE6F3 100%);padding:28px 32px;">
              <div style="width:40px;height:40px;background:#3D4E5C;border-radius:10px;display:inline-block;line-height:40px;text-align:center;color:#ffffff;font-weight:700;font-size:18px;">F</div>
              <div style="font-size:20px;font-weight:600;color:#1A202C;margin-top:12px;">Flown</div>
            </td>
          </tr>
          <tr>
            <td style="padding:28px 32px 8px;">
              <div style="font-size:16px;font-weight:600;color:#1A202C;">Olá, ${escapeHtml(userName)}</div>
              <div style="font-size:14px;color:#6B7B8F;margin-top:6px;">
                Você tem ${tasks.length} tarefa${tasks.length === 1 ? "" : "s"} vencendo em breve:
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:8px 16px 24px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                ${rows}
              </table>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

// Roda periodicamente (ver server.ts). Pra cada task dentro da janela de
// 24h, acha o estagio mais urgente ainda nao disparado e cria UMA
// notificacao + entra na lista do e-mail agrupado por usuario. Marca todos
// os estagios >= o disparado como enviados de uma vez - se o servidor ficou
// fora do ar e a task "pulou" direto pro estagio de 6h, nao faz sentido
// ainda mandar o de 24h/12h depois, so o mais urgente que coube.
export async function checkDueSoonReminders() {
  const tasks = await findTasksApproachingDue(MAX_WINDOW_HOURS);
  if (tasks.length === 0) return;

  const now = Date.now();
  const emailsByUser = new Map<string, { name: string; email: string; tasks: ReminderTask[] }>();

  for (const task of tasks) {
    const dueDate = task.dueDate as Date;
    const alreadySent = (task.remindersSent as number[] | null) ?? [];
    const hoursUntilDue = (dueDate.getTime() - now) / (60 * 60 * 1000);

    const crossedThresholds = THRESHOLD_HOURS.filter(
      (hours) => hoursUntilDue <= hours && !alreadySent.includes(hours)
    );
    if (crossedThresholds.length === 0) continue;

    const newThreshold = Math.min(...crossedThresholds);

    await createNotification({
      userId: task.userId,
      type: "due_soon",
      taskId: task.id,
      payload: { taskTitle: task.title, dueDate: dueDate.toISOString(), thresholdHours: newThreshold },
    });

    const updatedSent = Array.from(
      new Set([...alreadySent, ...THRESHOLD_HOURS.filter((hours) => hours >= newThreshold)])
    );
    await updateTaskRemindersSent(task.id, updatedSent);

    const entry = emailsByUser.get(task.userId) ?? { name: task.user.name, email: task.user.email, tasks: [] };
    entry.tasks.push({
      title: task.title,
      dueDate,
      projectName: task.project?.name ?? null,
      thresholdHours: newThreshold,
    });
    emailsByUser.set(task.userId, entry);
  }

  for (const [, entry] of emailsByUser) {
    const html = buildReminderEmailHtml(entry.name, entry.tasks);
    try {
      await sendEmail(entry.email, "Tarefas vencendo em breve — Flown", html);
    } catch (err) {
      console.error(`Failed to send reminder email to ${entry.email}:`, err);
    }
  }
}
