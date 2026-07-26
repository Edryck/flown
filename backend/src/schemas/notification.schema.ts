import Joi from "joi";

export const notificationResponseSchema = Joi.object({
  id: Joi.string().required(),
  type: Joi.string().required(),
  payload: Joi.object().unknown(true).required(),
  taskId: Joi.string().allow(null).required(),
  isRead: Joi.boolean().required(),
  createdAt: Joi.date().required(),
});
