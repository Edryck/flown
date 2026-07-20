import Joi from "joi";

export const createProjectSchema = Joi.object({
    name: Joi.string().trim().min(2).max(100).required(),
    description: Joi.string().trim().optional().allow(null),
    color: Joi.string().trim().pattern(/^#[0-9A-Fa-f]{6}$/).required(),
    typeId: Joi.string().trim().required(),
});

export const updateProjectSchema = Joi.object({
    name: Joi.string().trim().min(2).max(100).optional(),
    description: Joi.string().trim().optional().allow(null),
    color: Joi.string().trim().pattern(/^#[0-9A-Fa-f]{6}$/).optional(),
    typeId: Joi.string().trim().optional()
}).min(1).required();

export const projectResponseSchema = Joi.object({
    id: Joi.string().required(),
    name: Joi.string().required(),
    description: Joi.string().allow(null).required(),
    color: Joi.string().required(),
    isArchived: Joi.boolean().required(),
    isDeleted: Joi.boolean().required(),
    deletedAt: Joi.date().allow(null).required(),
    order: Joi.number().required(),
    typeId: Joi.string().required(),
    createdAt: Joi.date().required(),
    updatedAt: Joi.date().required(),
});
