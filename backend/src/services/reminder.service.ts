import { findTasksNeedingReminder, markRemindersSent } from "../repositories/task.repository.js";
import { sendEmail } from "../utils/mailer.js";

// Decisao do usuario (nao configuravel por env de proposito - unico valor
// pedido, sem necessidade real de ajustar em producao ainda).
const REMINDER_WINDOW_HOURS = 24;

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

type ReminderTask = { title: string; dueDate: Date; projectName: string | null };

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
                Você tem ${tasks.length} tarefa${tasks.length === 1 ? "" : "s"} vencendo nas próximas ${REMINDER_WINDOW_HOURS} horas:
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

// Roda periodicamente (ver server.ts) - agrupa por usuario pra mandar UM
// e-mail com todas as tarefas vencendo, nao um e-mail por tarefa. So marca
// `reminderSentAt` das tarefas cujo envio deu certo, entao uma falha de SMTP
// tenta de novo no proximo ciclo em vez de perder o lembrete.
export async function sendDueReminders() {
  const tasks = await findTasksNeedingReminder(REMINDER_WINDOW_HOURS);
  if (tasks.length === 0) return;

  const tasksByUser = new Map<string, { name: string; email: string; tasks: typeof tasks }>();
  for (const task of tasks) {
    const entry = tasksByUser.get(task.userId) ?? { name: task.user.name, email: task.user.email, tasks: [] };
    entry.tasks.push(task);
    tasksByUser.set(task.userId, entry);
  }

  const sentTaskIds: string[] = [];
  for (const [, entry] of tasksByUser) {
    const html = buildReminderEmailHtml(
      entry.name,
      entry.tasks.map((t) => ({ title: t.title, dueDate: t.dueDate as Date, projectName: t.project?.name ?? null }))
    );
    try {
      await sendEmail(entry.email, "Tarefas vencendo em breve — Flown", html);
      sentTaskIds.push(...entry.tasks.map((t) => t.id));
    } catch (err) {
      console.error(`Failed to send reminder email to ${entry.email}:`, err);
    }
  }

  if (sentTaskIds.length > 0) {
    await markRemindersSent(sentTaskIds);
  }
}
