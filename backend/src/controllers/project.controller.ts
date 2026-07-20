import type { FastifyReply, FastifyRequest } from "fastify";
import * as projectService from "../services/project.service.js";
import * as taskService from "../services/task.service.js";
import * as noteService from "../services/note.service.js";
import { createProjectSchema, projectResponseSchema, updateProjectSchema } from "../schemas/project.schema.js";
import { taskResponseSchema } from "../schemas/task.schema.js";
import { noteResponseSchema } from "../schemas/note.schema.js";
import { formatResponse } from "../utils/format-response.js";

function parseBoolean(value: unknown): boolean | undefined {
  if (value === "true") return true;
  if (value === "false") return false;
  return undefined;
}

export async function list(request: FastifyRequest, reply: FastifyReply) {
  const query = request.query as { isDeleted?: string; isArchived?: string };
  const projects = await projectService.list(request.user.id, {
    isDeleted: parseBoolean(query.isDeleted),
    isArchived: parseBoolean(query.isArchived),
  });
  return reply.status(200).send(formatResponse(projectResponseSchema, projects));
}

export async function create(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = createProjectSchema.validate(request.body);
  if (error) throw error;

  const project = await projectService.create(request.user.id, value);
  return reply.status(201).send(formatResponse(projectResponseSchema, project));
}

export async function getById(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const project = await projectService.getById(id, request.user.id);
  return reply.status(200).send(formatResponse(projectResponseSchema, project));
}

export async function update(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const { error, value } = updateProjectSchema.validate(request.body);
  if (error) throw error;

  const project = await projectService.update(id, request.user.id, value);
  return reply.status(200).send(formatResponse(projectResponseSchema, project));
}

export async function softDelete(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const project = await projectService.softDelete(id, request.user.id);
  return reply.status(200).send(formatResponse(projectResponseSchema, project));
}

export async function restore(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const project = await projectService.restore(id, request.user.id);
  return reply.status(200).send(formatResponse(projectResponseSchema, project));
}

export async function permanentDelete(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  await projectService.permanentDelete(id, request.user.id);
  return reply.status(204).send();
}

export async function archive(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const project = await projectService.archive(id, request.user.id);
  return reply.status(200).send(formatResponse(projectResponseSchema, project));
}

export async function unarchive(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const project = await projectService.unarchive(id, request.user.id);
  return reply.status(200).send(formatResponse(projectResponseSchema, project));
}

export async function listTasks(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  await projectService.getById(id, request.user.id);
  const tasks = await taskService.list(request.user.id, { projectId: id });
  return reply.status(200).send(formatResponse(taskResponseSchema, tasks));
}

export async function listNotes(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  await projectService.getById(id, request.user.id);
  const notes = await noteService.list(request.user.id, { projectId: id });
  return reply.status(200).send(formatResponse(noteResponseSchema, notes));
}
