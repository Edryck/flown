import type { FastifyReply, FastifyRequest } from "fastify";
import * as taskService from "../services/task.service.js";
import {
  createSubTaskSchema,
  createTaskSchema,
  reorderTaskSchema,
  taskResponseSchema,
  updateTaskSchema,
} from "../schemas/task.schema.js";
import { formatResponse } from "../utils/format-response.js";

function parseBoolean(value: unknown): boolean | undefined {
  if (value === "true") return true;
  if (value === "false") return false;
  return undefined;
}

export async function list(request: FastifyRequest, reply: FastifyReply) {
  const query = request.query as {
    projectId?: string;
    isDeleted?: string;
    isArchived?: string;
    q?: string;
    tag?: string;
  };
  const tasks = await taskService.list(request.user.id, {
    projectId: query.projectId,
    isDeleted: parseBoolean(query.isDeleted),
    isArchived: parseBoolean(query.isArchived),
    search: query.q,
    tag: query.tag,
  });
  return reply.status(200).send(formatResponse(taskResponseSchema, tasks));
}

export async function create(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = createTaskSchema.validate(request.body);
  if (error) throw error;

  const task = await taskService.create(request.user.id, value);
  return reply.status(201).send(formatResponse(taskResponseSchema, task));
}

export async function getById(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const task = await taskService.getById(id, request.user.id);
  return reply.status(200).send(formatResponse(taskResponseSchema, task));
}

export async function update(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const { error, value } = updateTaskSchema.validate(request.body);
  if (error) throw error;

  const task = await taskService.update(id, request.user.id, value);
  return reply.status(200).send(formatResponse(taskResponseSchema, task));
}

export async function softDelete(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const task = await taskService.softDelete(id, request.user.id);
  return reply.status(200).send(formatResponse(taskResponseSchema, task));
}

export async function restore(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const task = await taskService.restore(id, request.user.id);
  return reply.status(200).send(formatResponse(taskResponseSchema, task));
}

export async function permanentDelete(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  await taskService.permanentDelete(id, request.user.id);
  return reply.status(204).send();
}

export async function archive(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const task = await taskService.archive(id, request.user.id);
  return reply.status(200).send(formatResponse(taskResponseSchema, task));
}

export async function unarchive(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const task = await taskService.unarchive(id, request.user.id);
  return reply.status(200).send(formatResponse(taskResponseSchema, task));
}

export async function reorder(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = reorderTaskSchema.validate(request.body);
  if (error) throw error;

  await taskService.reorder(request.user.id, value.items);
  return reply.status(204).send();
}

export async function listSubtasks(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const subtasks = await taskService.listSubtasks(id, request.user.id);
  return reply.status(200).send(formatResponse(taskResponseSchema, subtasks));
}

export async function createSubtask(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const { error, value } = createSubTaskSchema.validate(request.body);
  if (error) throw error;

  const subtask = await taskService.create(request.user.id, { ...value, parentTaskId: id });
  return reply.status(201).send(formatResponse(taskResponseSchema, subtask));
}
