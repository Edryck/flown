import bcrypt from "bcrypt";
import crypto from "node:crypto";
import { AppError } from "../utils/errors.js";
import { signAccessToken, signRefreshToken, verifyRefreshToken } from "../utils/jwt.js";
import {
  createUser,
  createUserFromGoogle,
  findUserByEmail,
  findUserByGoogleId,
  findUserById,
  linkGoogleAccount,
  updateUserPassword,
} from "../repositories/user.repository.js";
import {
  createRefreshToken,
  deleteRefreshTokenByToken,
  deleteRefreshTokensByUserId,
  findRefreshTokenByToken,
} from "../repositories/refresh-token.repository.js";
import {
  consumeOAuthHandoff,
  consumeOAuthState,
  createOAuthHandoff,
  createOAuthState,
  type OAuthReturnTarget,
} from "../utils/oauth-state-store.js";

const BCRYPT_SALT_ROUNDS = 10;
const REFRESH_TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000;

function hashToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}

async function issueTokens(userId: string) {
  const accessToken = signAccessToken(userId);
  const refreshToken = signRefreshToken(userId);
  await createRefreshToken({
    userId,
    token: hashToken(refreshToken),
    expiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_MS),
  });
  return { accessToken, refreshToken };
}

export async function register(data: { name: string; email: string; password: string }) {
  if (process.env["ALLOW_REGISTER"] === "false") {
    throw new AppError(403, "Registration is disabled");
  }

  const existing = await findUserByEmail(data.email);
  if (existing) {
    throw new AppError(409, "Email already in use");
  }

  const passwordHash = await bcrypt.hash(data.password, BCRYPT_SALT_ROUNDS);
  const user = await createUser({ name: data.name, email: data.email, password: passwordHash });

  const tokens = await issueTokens(user.id);
  return { ...tokens, user };
}

export async function login(data: { email: string; password: string }) {
  const user = await findUserByEmail(data.email);
  if (!user || !user.password) {
    throw new AppError(401, "Invalid credentials");
  }

  const passwordMatches = await bcrypt.compare(data.password, user.password);
  if (!passwordMatches) {
    throw new AppError(401, "Invalid credentials");
  }

  const tokens = await issueTokens(user.id);
  return { ...tokens, user };
}

export async function refresh(refreshToken: string) {
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    throw new AppError(401, "Invalid or expired refresh token");
  }

  const stored = await findRefreshTokenByToken(hashToken(refreshToken));
  if (!stored || stored.expiresAt < new Date()) {
    throw new AppError(401, "Invalid or expired refresh token");
  }

  const user = await findUserById(payload.sub);
  if (!user) {
    throw new AppError(401, "Invalid or expired refresh token");
  }

  return { accessToken: signAccessToken(user.id) };
}

export async function logout(refreshToken: string) {
  await deleteRefreshTokenByToken(hashToken(refreshToken));
}

export async function changePassword(
  userId: string,
  data: { currentPassword: string; newPassword: string }
) {
  const user = await findUserById(userId);
  if (!user) {
    throw new AppError(404, "User not found");
  }
  if (!user.password) {
    throw new AppError(400, "This account uses Google Sign-In and has no password to change");
  }

  const passwordMatches = await bcrypt.compare(data.currentPassword, user.password);
  if (!passwordMatches) {
    throw new AppError(401, "Current password is incorrect");
  }

  const newPasswordHash = await bcrypt.hash(data.newPassword, BCRYPT_SALT_ROUNDS);
  await updateUserPassword(userId, newPasswordHash);
  await deleteRefreshTokensByUserId(userId);
}

function getGoogleEnv() {
  const clientId = process.env["GOOGLE_CLIENT_ID"];
  const clientSecret = process.env["GOOGLE_CLIENT_SECRET"];
  const redirectUri = process.env["GOOGLE_REDIRECT_URI"];
  if (!clientId || !clientSecret || !redirectUri) {
    throw new AppError(500, "Google OAuth is not configured");
  }
  return { clientId, clientSecret, redirectUri };
}

export function buildGoogleAuthorizeUrl(returnTo: OAuthReturnTarget): string {
  const { clientId, redirectUri } = getGoogleEnv();
  const state = createOAuthState(returnTo);

  const url = new URL("https://accounts.google.com/o/oauth2/v2/auth");
  url.searchParams.set("client_id", clientId);
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("scope", "openid email profile");
  url.searchParams.set("state", state);
  url.searchParams.set("prompt", "select_account");
  return url.toString();
}

// Resolve o `returnTo` de um `state`, mesmo em caso de erro/cancelamento no
// Google (o callback ainda precisa saber pra onde redirecionar de volta).
export function resolvePendingOAuthState(state: string): OAuthReturnTarget | null {
  return consumeOAuthState(state);
}

type GoogleUserInfo = { sub: string; email: string; email_verified: boolean; name: string };

async function exchangeGoogleCode(code: string): Promise<GoogleUserInfo> {
  const { clientId, clientSecret, redirectUri } = getGoogleEnv();

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: clientId,
      client_secret: clientSecret,
      redirect_uri: redirectUri,
      grant_type: "authorization_code",
    }),
  });
  if (!tokenResponse.ok) {
    throw new AppError(401, "Failed to exchange Google authorization code");
  }
  const tokens = (await tokenResponse.json()) as { access_token: string };

  const userInfoResponse = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
    headers: { Authorization: `Bearer ${tokens.access_token}` },
  });
  if (!userInfoResponse.ok) {
    throw new AppError(401, "Failed to fetch Google profile");
  }
  const userInfo = (await userInfoResponse.json()) as GoogleUserInfo;
  if (!userInfo.email_verified) {
    throw new AppError(401, "Google email is not verified");
  }
  return userInfo;
}

export async function handleGoogleCallback(code: string, returnTo: OAuthReturnTarget) {
  const profile = await exchangeGoogleCode(code);

  let user = await findUserByGoogleId(profile.sub);
  if (!user) {
    const existing = await findUserByEmail(profile.email);
    if (existing) {
      // Mesmo e-mail ja tem conta local (senha) — vincula em vez de criar
      // duplicata, mantendo o login por senha funcionando como alternativa.
      user = await linkGoogleAccount(existing.id, profile.sub);
    } else {
      if (process.env["ALLOW_REGISTER"] === "false") {
        throw new AppError(403, "Registration is disabled");
      }
      user = await createUserFromGoogle({ name: profile.name, email: profile.email, googleId: profile.sub });
    }
  }

  const tokens = await issueTokens(user.id);
  const handoff = createOAuthHandoff(tokens);
  return { handoff, returnTo };
}

export async function exchangeGoogleHandoff(handoff: string) {
  const tokens = consumeOAuthHandoff(handoff);
  if (!tokens) {
    throw new AppError(400, "Invalid or expired login handoff");
  }
  return tokens;
}