import Joi from "joi";

const checklistItemSchema = Joi.object({
  text: Joi.string().trim().required(),
  done: Joi.boolean().required(),
});

export const createTaskSchema = Joi.object({
  title: Joi.string().trim().min(2).max(100).required(),
  description: Joi.string().trim().optional().allow(null),
  status: Joi.string().optional(),
  priority: Joi.string().valid("Low", "Medium", "High").optional(),
  dueDate: Joi.date().optional().allow(null),
  progress: Joi.number().min(0).max(100).optional().allow(null),
  estimatedTime: Joi.string().optional().allow(null),
  tags: Joi.array().items(Joi.string()).optional().default([]),
  checklist: Joi.array().items(checklistItemSchema).optional().default([]),
  projectId: Joi.string().optional().allow(null),
  parentTaskId: Joi.string().optional().allow(null),
});

export const updateTaskSchema = Joi.object({
  title: Joi.string().trim().min(2).max(100).optional(),
  description: Joi.string().trim().optional().allow(null),
  status: Joi.string().optional(),
  priority: Joi.string().valid("Low", "Medium", "High").optional(),
  dueDate: Joi.date().optional().allow(null),
  progress: Joi.number().min(0).max(100).optional().allow(null),
  estimatedTime: Joi.string().optional().allow(null),
  tags: Joi.array().items(Joi.string()).optional(),
  checklist: Joi.array().items(checklistItemSchema).optional(),
  projectId: Joi.string().optional().allow(null),
  parentTaskId: Joi.string().optional().allow(null),
}).min(1);

export const reorderTaskSchema = Joi.object({
  items: Joi.array()
    .items(
      Joi.object({
        id: Joi.string().required(),
        order: Joi.number().integer().min(0).required(),
      })
    )
    .min(1)
    .required(),
});

export const createSubTaskSchema = Joi.object({
  title: Joi.string().trim().min(2).max(100).required(),
  description: Joi.string().trim().optional().allow(null),
  status: Joi.string().optional(),
  priority: Joi.string().valid("Low", "Medium", "High").optional(),
  dueDate: Joi.date().optional().allow(null),
  progress: Joi.number().min(0).max(100).optional().allow(null),
  estimatedTime: Joi.string().optional().allow(null),
  tags: Joi.array().items(Joi.string()).optional().default([]),
  checklist: Joi.array().items(checklistItemSchema).optional().default([]),
  projectId: Joi.string().optional().allow(null),
});

export const taskResponseSchema = Joi.object({
  id: Joi.string().required(),
  title: Joi.string().required(),
  description: Joi.string().allow(null).required(),
  status: Joi.string().required(),
  priority: Joi.string().valid("Low", "Medium", "High").required(),
  dueDate: Joi.date().allow(null).required(),
  progress: Joi.number().allow(null).required(),
  estimatedTime: Joi.string().allow(null).required(),
  tags: Joi.array().items(Joi.string()).required(),
  checklist: Joi.array().items(checklistItemSchema).required(),
  order: Joi.number().required(),
  isDeleted: Joi.boolean().required(),
  deletedAt: Joi.date().allow(null).required(),
  completedAt: Joi.date().allow(null).required(),
  projectId: Joi.string().allow(null).required(),
  parentTaskId: Joi.string().allow(null).required(),
  createdAt: Joi.date().required(),
  updatedAt: Joi.date().required(),
});
