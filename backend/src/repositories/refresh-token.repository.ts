import { prisma } from "../utils/prisma.js";

export async function createRefreshToken(data: { userId: string; token: string; expiresAt: Date }) {
  return prisma.refreshToken.create({ data });
}

export async function findRefreshTokenByToken(token: string) {
  return prisma.refreshToken.findUnique({ where: { token } });
}

export async function deleteRefreshTokenByToken(token: string) {
  return prisma.refreshToken.deleteMany({ where: { token } });
}

export async function deleteRefreshTokensByUserId(userId: string) {
  return prisma.refreshToken.deleteMany({ where: { userId } });
}

export async function deleteExpiredRefreshTokens() {
  return prisma.refreshToken.deleteMany({ where: { expiresAt: { lt: new Date() } } });
}
