import type { Schema } from "joi";

export function formatResponse(schema: Schema, data: unknown): unknown {
  if (Array.isArray(data)) {
    return data.map((item) => formatResponse(schema, item));
  }
  const { value, error } = schema.validate(data, { stripUnknown: true });
  if (error) {
    throw error;
  }
  return value;
}
