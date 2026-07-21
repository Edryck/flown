FROM node:22-bookworm-slim

WORKDIR /app

# better-sqlite3 (driver adapter do Prisma) e um addon nativo — a maioria
# das combinacoes de plataforma tem prebuild pronto, mas isso garante que
# compila do fonte se precisar, sem quebrar a imagem.
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

EXPOSE 3333

# Regenera o client do Prisma e aplica migrations pendentes toda vez que o
# container sobe (o schema/migrations vem do bind mount, pode ter mudado
# sem rebuild de imagem), depois inicia com hot-reload via tsx watch.
CMD ["sh", "-c", "npx prisma generate && npx prisma migrate deploy && npx tsx watch src/server.ts"]
