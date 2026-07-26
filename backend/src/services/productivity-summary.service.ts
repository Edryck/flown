import { prisma } from "../utils/prisma.js";
import { countCompletedTasksInRange } from "../repositories/task.repository.js";
import { createNotification, findRecentProductivitySummaries } from "../repositories/notification.repository.js";
import { sendEmail } from "../utils/mailer.js";

type Period = "weekly" | "monthly";

function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function startOfWeek(date: Date): Date {
  const day = startOfDay(date);
  return new Date(day.getTime() - day.getDay() * 24 * 60 * 60 * 1000);
}

function startOfMonth(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), 1);
}

async function alreadyGeneratedThisPeriod(userId: string, period: Period, currentPeriodStart: Date): Promise<boolean> {
  const recent = await findRecentProductivitySummaries(userId, currentPeriodStart);
  return recent.some((notification) => (notification.payload as { period?: string }).period === period);
}

function formatEmailSubject(period: Period): string {
  return period === "weekly" ? "Seu resumo semanal — Flown" : "Seu resumo mensal — Flown";
}

function formatPeriodLabel(period: Period): string {
  return period === "weekly" ? "semana passada" : "mês passado";
}

function buildSummaryEmailHtml(
  userName: string,
  period: Period,
  completedThisPeriod: number,
  completedLastPeriod: number,
  percentChange: number | null
): string {
  const diff = completedThisPeriod - completedLastPeriod;
  const diffLabel = diff === 0 ? "igual ao período anterior" : diff > 0 ? `${diff} a mais` : `${Math.abs(diff)} a menos`;
  const percentLabel =
    percentChange === null
      ? ""
      : percentChange === 0
        ? " (mesma produtividade)"
        : percentChange > 0
          ? ` (${percentChange}% mais produtivo)`
          : ` (${Math.abs(percentChange)}% menos produtivo)`;

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
            <td style="padding:28px 32px 32px;">
              <div style="font-size:16px;font-weight:600;color:#1A202C;">Olá, ${userName}</div>
              <div style="font-size:14px;color:#6B7B8F;margin-top:10px;line-height:1.6;">
                Na ${formatPeriodLabel(period)} você concluiu <strong style="color:#1A202C;">${completedThisPeriod} tarefa${completedThisPeriod === 1 ? "" : "s"}</strong>
                — ${diffLabel} que no período anterior (${completedLastPeriod})${percentLabel}.
              </div>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

async function maybeGenerateSummary(
  user: { id: string; name: string; email: string },
  period: Period,
  currentPeriodStart: Date
) {
  const alreadyDone = await alreadyGeneratedThisPeriod(user.id, period, currentPeriodStart);
  if (alreadyDone) return;

  // Compara os dois periodos ANTERIORES completos (ex: semana passada vs
  // retrasada) - gerado assim que o periodo atual comeca, nao no fim dele.
  const completedPeriodEnd = currentPeriodStart;
  const completedPeriodStart =
    period === "weekly"
      ? new Date(currentPeriodStart.getTime() - 7 * 24 * 60 * 60 * 1000)
      : new Date(currentPeriodStart.getFullYear(), currentPeriodStart.getMonth() - 1, 1);
  const priorPeriodEnd = completedPeriodStart;
  const priorPeriodStart =
    period === "weekly"
      ? new Date(completedPeriodStart.getTime() - 7 * 24 * 60 * 60 * 1000)
      : new Date(completedPeriodStart.getFullYear(), completedPeriodStart.getMonth() - 1, 1);

  const completedThisPeriod = await countCompletedTasksInRange(user.id, completedPeriodStart, completedPeriodEnd);
  const completedLastPeriod = await countCompletedTasksInRange(user.id, priorPeriodStart, priorPeriodEnd);

  // Nada pra comparar ainda (usuario novo, por exemplo) - nao gera resumo vazio.
  if (completedThisPeriod === 0 && completedLastPeriod === 0) return;

  const percentChange =
    completedLastPeriod > 0
      ? Math.round(((completedThisPeriod - completedLastPeriod) / completedLastPeriod) * 100)
      : null;

  await createNotification({
    userId: user.id,
    type: "productivity_summary",
    payload: { period, completedThisPeriod, completedLastPeriod, percentChange },
  });

  const html = buildSummaryEmailHtml(user.name, period, completedThisPeriod, completedLastPeriod, percentChange);
  try {
    await sendEmail(user.email, formatEmailSubject(period), html);
  } catch (err) {
    console.error(`Failed to send productivity summary email to ${user.email}:`, err);
  }
}

// Roda periodicamente (ver server.ts) - idempotente, cada usuario so recebe
// 1 resumo semanal e 1 mensal por periodo (checagem via notificacoes ja
// criadas, sem precisar de coluna nova em User).
export async function checkProductivitySummaries() {
  const users = await prisma.user.findMany({ select: { id: true, name: true, email: true } });
  const now = new Date();

  for (const user of users) {
    await maybeGenerateSummary(user, "weekly", startOfWeek(now));
    await maybeGenerateSummary(user, "monthly", startOfMonth(now));
  }
}
