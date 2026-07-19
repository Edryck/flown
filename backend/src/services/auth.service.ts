import bcrypt from "bcrypt";
import crypto from "node:crypto";
import { AppError } from "../utils/errors.js";
import { signAccessToken, signRefreshToken, verifyRefreshToken } from "../utils/jwt.js";
import { createUser, findUserByEmail, findUserById, updateUserPassword } from "../repositories/user.repository.js";
import {
  createRefreshToken,
  deleteRefreshTokenByToken,
  deleteRefreshTokensByUserId,
  findRefreshTokenByToken,
} from "../repositories/refresh-token.repository.js";

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
  if (!user) {
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

  const passwordMatches = await bcrypt.compare(data.currentPassword, user.password);
  if (!passwordMatches) {
    throw new AppError(401, "Current password is incorrect");
  }

  const newPasswordHash = await bcrypt.hash(data.newPassword, BCRYPT_SALT_ROUNDS);
  await updateUserPassword(userId, newPasswordHash);
  await deleteRefreshTokensByUserId(userId);
}