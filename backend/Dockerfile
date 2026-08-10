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

# `generate`/`migrate deploy` NÃO rodam mais aqui — ficam só no serviço
# `database` do compose (roda uma vez e sai; `backend` espera ele terminar
# via `depends_on: condition: service_completed_successfully`). Restart do
# `backend` por mudança de código não precisa mais esperar migration/generate
# toda vez.
CMD ["npx", "tsx", "watch", "src/server.ts"]
