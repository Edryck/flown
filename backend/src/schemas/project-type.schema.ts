import Joi from "joi";

export const createProjectTypeSchema = Joi.object({
    name: Joi.string().trim().required(),
    availableStatus: Joi.array().items(Joi.string()).min(1).required(),
});

export const projectTypeResponseSchema = Joi.object({
    id: Joi.string().required(),
    name: Joi.string().required(),
    availableStatus: Joi.array().items(Joi.string()).required(),
});
