import type { FastifyReply, FastifyRequest } from "fastify";
import * as authService from "../services/auth.service.js";
import {
  authResponseSchema,
  changePasswordSchema,
  googleAuthorizeQuerySchema,
  googleCallbackQuerySchema,
  googleExchangeResponseSchema,
  googleExchangeSchema,
  loginSchema,
  refreshResponseSchema,
  refreshSchema,
  registerSchema,
} from "../schemas/auth.schema.js";
import { formatResponse } from "../utils/format-response.js";
import type { OAuthReturnTarget } from "../utils/oauth-state-store.js";

export async function register(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = registerSchema.validate(request.body);
  if (error) throw error;

  const result = await authService.register(value);
  return reply.status(201).send(formatResponse(authResponseSchema, result));
}

export async function login(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = loginSchema.validate(request.body);
  if (error) throw error;

  const result = await authService.login(value);
  return reply.status(200).send(formatResponse(authResponseSchema, result));
}

export async function refresh(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = refreshSchema.validate(request.body);
  if (error) throw error;

  const result = await authService.refresh(value.refreshToken);
  return reply.status(200).send(formatResponse(refreshResponseSchema, result));
}

export async function logout(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = refreshSchema.validate(request.body);
  if (error) throw error;

  await authService.logout(value.refreshToken);
  return reply.status(204).send();
}

export async function changePassword(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = changePasswordSchema.validate(request.body);
  if (error) throw error;

  await authService.changePassword(request.user.id, value);
  return reply.status(204).send();
}

// Sem auth de propósito — a tela de login precisa saber ANTES de logar se
// o botão de bypass de dev faz sentido (backend com SKIP_AUTH=true), então
// não pode exigir um token pra responder essa pergunta.
export async function devMode(_request: FastifyRequest, reply: FastifyReply) {
  return reply.status(200).send({ skipAuth: process.env["SKIP_AUTH"] === "true" });
}

// Monta a URL final que devolve o controle pro app depois do login: um
// servidor HTTP local temporario (Desktop, `redirectPort`) ou a propria
// origem do app (Web, `webRedirect`) — ver oauth-state-store.ts.
function buildReturnUrl(returnTo: OAuthReturnTarget, params: Record<string, string>): string {
  const query = new URLSearchParams(params).toString();
  if (returnTo.kind === "loopback") {
    return `http://127.0.0.1:${returnTo.port}/callback?${query}`;
  }
  return `${returnTo.origin}?${query}`;
}

export async function googleAuthorize(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = googleAuthorizeQuerySchema.validate(request.query);
  if (error) throw error;

  const returnTo: OAuthReturnTarget =
    value.redirectPort !== undefined
      ? { kind: "loopback", port: value.redirectPort }
      : { kind: "web", origin: value.webRedirect };

  const url = authService.buildGoogleAuthorizeUrl(returnTo);
  return reply.redirect(url);
}

export async function googleCallback(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = googleCallbackQuerySchema.validate(request.query);
  if (error) throw error;

  const returnTo = authService.resolvePendingOAuthState(value.state);
  if (!returnTo) {
    return reply.status(400).send({ message: "Invalid or expired Google login attempt" });
  }

  if (value.error) {
    return reply.redirect(buildReturnUrl(returnTo, { error: value.error }));
  }

  const { handoff } = await authService.handleGoogleCallback(value.code as string, returnTo);
  return reply.redirect(buildReturnUrl(returnTo, { handoff }));
}

export async function googleExchange(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = googleExchangeSchema.validate(request.body);
  if (error) throw error;

  const tokens = await authService.exchangeGoogleHandoff(value.handoff);
  return reply.status(200).send(formatResponse(googleExchangeResponseSchema, tokens));
}
