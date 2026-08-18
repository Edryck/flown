import type { FastifyReply, FastifyRequest } from "fastify";
import * as noteService from "../services/note.service.js";
import { createNoteSchema, noteResponseSchema, reorderNoteSchema, updateNoteSchema } from "../schemas/note.schema.js";
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
  const notes = await noteService.list(request.user.id, {
    projectId: query.projectId,
    isDeleted: parseBoolean(query.isDeleted),
    isArchived: parseBoolean(query.isArchived),
    search: query.q,
    tag: query.tag,
  });
  return reply.status(200).send(formatResponse(noteResponseSchema, notes));
}

export async function create(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = createNoteSchema.validate(request.body);
  if (error) throw error;

  const note = await noteService.create(request.user.id, value);
  return reply.status(201).send(formatResponse(noteResponseSchema, note));
}

export async function getById(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const note = await noteService.getById(id, request.user.id);
  return reply.status(200).send(formatResponse(noteResponseSchema, note));
}

export async function update(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const { error, value } = updateNoteSchema.validate(request.body);
  if (error) throw error;

  const note = await noteService.update(id, request.user.id, value);
  return reply.status(200).send(formatResponse(noteResponseSchema, note));
}

export async function softDelete(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const note = await noteService.softDelete(id, request.user.id);
  return reply.status(200).send(formatResponse(noteResponseSchema, note));
}

export async function restore(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const note = await noteService.restore(id, request.user.id);
  return reply.status(200).send(formatResponse(noteResponseSchema, note));
}

export async function permanentDelete(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  await noteService.permanentDelete(id, request.user.id);
  return reply.status(204).send();
}

export async function archive(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const note = await noteService.archive(id, request.user.id);
  return reply.status(200).send(formatResponse(noteResponseSchema, note));
}

export async function unarchive(request: FastifyRequest, reply: FastifyReply) {
  const { id } = request.params as { id: string };
  const note = await noteService.unarchive(id, request.user.id);
  return reply.status(200).send(formatResponse(noteResponseSchema, note));
}

export async function reorder(request: FastifyRequest, reply: FastifyReply) {
  const { error, value } = reorderNoteSchema.validate(request.body);
  if (error) throw error;

  await noteService.reorder(request.user.id, value.items);
  return reply.status(204).send();
}
