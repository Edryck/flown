import Joi from "joi";

export const createNoteSchema = Joi.object({
  title: Joi.string().trim().min(2).max(100).required(),
  content: Joi.string().trim().required(),
  tags: Joi.array().items(Joi.string()).optional().default([]),
  isPinned: Joi.boolean().optional(),
  projectId: Joi.string().optional().allow(null),
});

export const updateNoteSchema = Joi.object({
  title: Joi.string().trim().min(2).max(100).optional(),
  content: Joi.string().trim().optional(),
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
