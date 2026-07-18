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
