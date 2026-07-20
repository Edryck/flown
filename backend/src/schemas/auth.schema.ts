import Joi from "joi";
import { userResponseSchema } from "./user.schema.js";

export const registerSchema = Joi.object({
    name: Joi.string().trim().min(2).max(100).required(),
    email: Joi.string().trim().lowercase().email().required(),
    password: Joi.string().min(8).required(),
});

export const loginSchema = Joi.object({
    email: Joi.string().trim().lowercase().email().required(),
    password: Joi.string().min(8).required(),
});

export const refreshSchema = Joi.object({
    refreshToken: Joi.string().trim().required(),
});

export const changePasswordSchema = Joi.object({
    currentPassword: Joi.string().min(8).required(),
    newPassword: Joi.string().min(10).required()
});

export const authResponseSchema = Joi.object({
    accessToken: Joi.string(),
    refreshToken: Joi.string(),
    user: userResponseSchema,
});

export const refreshResponseSchema = Joi.object({
    accessToken: Joi.string().required(),
});