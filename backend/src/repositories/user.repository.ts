import { prisma } from "../utils/prisma.js";

export async function createUser(data: { name: string; email: string; password: string }) {
  return prisma.user.create({ data });
}

export async function findUserById(id: string) {
  return prisma.user.findUnique({ where: { id } });
}

export async function findUserByEmail(email: string) {
  return prisma.user.findUnique({ where: { email } });
}

export async function findUserByGoogleId(googleId: string) {
  return prisma.user.findUnique({ where: { googleId } });
}

export async function linkGoogleAccount(id: string, googleId: string) {
  return prisma.user.update({ where: { id }, data: { googleId } });
}

export async function createUserFromGoogle(data: { name: string; email: string; googleId: string }) {
  return prisma.user.create({ data: { name: data.name, email: data.email, googleId: data.googleId } });
}

export async function updateUser(id: string, data: { name?: string; email?: string }) {
  return prisma.user.update({ where: { id }, data });
}

export async function updateUserPassword(id: string, password: string) {
  return prisma.user.update({ where: { id }, data: { password } });
}
