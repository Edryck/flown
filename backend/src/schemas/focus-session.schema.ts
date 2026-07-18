import Joi from "joi";

export const createFocusSessionSchema = Joi.object({
  type: Joi.string().valid("pomodoro", "stopwatch").required(),
  durationSeconds: Joi.number().integer().min(1).required(),
  startedAt: Joi.date().required(),
  completedAt: Joi.date().optional().allow(null),
  taskId: Joi.string().optional().allow(null),
});

export const updateFocusSessionSchema = Joi.object({
  type: Joi.string().valid("pomodoro", "stopwatch").optional(),
  durationSeconds: Joi.number().integer().min(1).optional(),
  startedAt: Joi.date().optional(),
  completedAt: Joi.date().optional().allow(null),
  taskId: Joi.string().optional().allow(null),
}).min(1);

export const completeFocusSessionSchema = Joi.object({
  completedAt: Joi.date().optional(),
});
