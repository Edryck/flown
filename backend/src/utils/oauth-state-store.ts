import crypto from "node:crypto";

// Guarda em memoria de proposito: cada entrada e de uso unico e vive no
// maximo alguns minutos (o tempo do usuario logar no Google) — persistir
// isso em tabela seria complexidade sem beneficio pra um processo unico.

export type OAuthReturnTarget = { kind: "loopback"; port: number } | { kind: "web"; origin: string };

type PendingState = { createdAt: number; returnTo: OAuthReturnTarget };
type Handoff = { createdAt: number; accessToken: string; refreshToken: string };

const STATE_TTL_MS = 5 * 60 * 1000; // tempo pro usuario logar/autorizar no Google
const HANDOFF_TTL_MS = 60 * 1000; // handoff so precisa sobreviver ao redirect final

const pendingStates = new Map<string, PendingState>();
const handoffs = new Map<string, Handoff>();

function purgeExpired<T extends { createdAt: number }>(map: Map<string, T>, ttlMs: number) {
  const now = Date.now();
  for (const [key, value] of map) {
    if (now - value.createdAt > ttlMs) map.delete(key);
  }
}

export function createOAuthState(returnTo: OAuthReturnTarget): string {
  purgeExpired(pendingStates, STATE_TTL_MS);
  const state = crypto.randomUUID();
  pendingStates.set(state, { createdAt: Date.now(), returnTo });
  return state;
}

export function consumeOAuthState(state: string): OAuthReturnTarget | null {
  purgeExpired(pendingStates, STATE_TTL_MS);
  const entry = pendingStates.get(state);
  if (!entry) return null;
  pendingStates.delete(state);
  return entry.returnTo;
}

export function createOAuthHandoff(tokens: { accessToken: string; refreshToken: string }): string {
  purgeExpired(handoffs, HANDOFF_TTL_MS);
  const code = crypto.randomUUID();
  handoffs.set(code, { createdAt: Date.now(), ...tokens });
  return code;
}

export function consumeOAuthHandoff(code: string): { accessToken: string; refreshToken: string } | null {
  purgeExpired(handoffs, HANDOFF_TTL_MS);
  const entry = handoffs.get(code);
  if (!entry) return null;
  handoffs.delete(code);
  return { accessToken: entry.accessToken, refreshToken: entry.refreshToken };
}
