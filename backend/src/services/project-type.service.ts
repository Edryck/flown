import { AppError } from "../utils/errors.js";
import { createProjectType, findAllProjectTypes, findProjectTypeByName } from "../repositories/project-type.repository.js";

export async function create(data: { name: string; availableStatus: string[] }) {
  const existing = await findProjectTypeByName(data.name);
  if (existing) {
    throw new AppError(409, "Project type name already in use");
  }
  return createProjectType(data);
}

export async function list() {
  return findAllProjectTypes();
}