import Joi from "joi";

export const createNoteSchema = Joi.object({
  title: Joi.string().trim().min(2).max(100).required(),
  content: Joi.string().trim().required(),
  color: Joi.string().trim().pattern(/^#[0-9A-Fa-f]{6}$/).optional(),
  tags: Joi.array().items(Joi.string()).optional().default([]),
  isPinned: Joi.boolean().optional(),
  projectId: Joi.string().optional().allow(null),
});

export const updateNoteSchema = Joi.object({
  title: Joi.string().trim().min(2).max(100).optional(),
  content: Joi.string().trim().optional(),
  color: Joi.string().trim().pattern(/^#[0-9A-Fa-f]{6}$/).optional(),
  tags: Joi.array().items(Joi.string()).optional(),
  isPinned: Joi.boolean().optional(),
  projectId: Joi.string().optional().allow(null),
}).min(1);

export const reorderNoteSchema = Joi.object({
  items: Joi.array().items(
      Joi.object({
        id: Joi.string().required(),
        order: Joi.number().integer().min(0).required(),
      })
    ).min(1).required(),
});

export const noteResponseSchema = Joi.object({
  id: Joi.string().required(),
  title: Joi.string().required(),
  content: Joi.string().required(),
  color: Joi.string().required(),
  tags: Joi.array().items(Joi.string()).required(),
  isPinned: Joi.boolean().required(),
  order: Joi.number().required(),
  isDeleted: Joi.boolean().required(),
  deletedAt: Joi.date().allow(null).required(),
  projectId: Joi.string().allow(null).required(),
  createdAt: Joi.date().required(),
  updatedAt: Joi.date().required(),
});
