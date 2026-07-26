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

// `redirectPort` (Desktop, servidor HTTP local temporario) e `webRedirect`
// (Web, URL de origem do proprio app) sao mutuamente exclusivos — a rota
// so sabe montar UM jeito de devolver o handoff no final do login.
export const googleAuthorizeQuerySchema = Joi.object({
    redirectPort: Joi.number().integer().min(1).max(65535),
    webRedirect: Joi.string().uri(),
}).xor("redirectPort", "webRedirect");

// `.unknown(true)` de proposito — o Google manda outros campos no redirect
// alem dos que usamos (`iss`, `scope`, `authuser`, `prompt`, `hd`...), e
// esse conjunto pode mudar sem aviso. So validamos os 3 que o callback
// realmente le, ignorando o resto.
export const googleCallbackQuerySchema = Joi.object({
    code: Joi.string(),
    state: Joi.string().required(),
    error: Joi.string(),
})
    .xor("code", "error")
    .unknown(true);

export const googleExchangeSchema = Joi.object({
    handoff: Joi.string().required(),
});

export const googleExchangeResponseSchema = Joi.object({
    accessToken: Joi.string().required(),
    refreshToken: Joi.string().required(),
});