import { AppError } from "../utils/errors.js";
import { findUserByEmail, findUserById, updateUser } from "../repositories/user.repository.js";

export async function getById(userId: string) {
  const user = await findUserById(userId);
  if (!user) {
    throw new AppError(404, "User not found");
  }
  return user;
}

export async function updateProfile(
  userId: string,
  data: { name?: string; email?: string; taskArchiveDays?: number; projectArchiveDays?: number }
) {
  if (data.email) {
    const existing = await findUserByEmail(data.email);
    if (existing && existing.id !== userId) {
      throw new AppError(409, "Email already in use");
    }
  }
  return updateUser(userId, data);
}