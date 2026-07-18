import Joi from "joi";

export const createProjectTypeSchema = Joi.object({
    name: Joi.string().trim().required(),
    availableStatus: Joi.array().items(Joi.string()).min(1).required(),
});
