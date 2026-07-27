# Flown

App de gerenciamento de tarefas e gestão de tempo, para uso pessoal. Documentação completa em [`docs/FLOWN_DOC.md`](docs/FLOWN_DOC.md).

## Stack

- **Backend**: Fastify + TypeScript, Prisma (SQLite), Joi, JWT + bcrypt
- **Frontend**: Flutter + Dart, Riverpod

## Rodando localmente

Projeto 100% local — sem dependência de nuvem ou Docker para rodar.

### Backend

```
cd backend
npm install
npx prisma generate
npx prisma migrate deploy
npm run dev
```

Copie `.env.example` para `.env` e preencha as variáveis antes de subir o servidor.

### Frontend

```
cd frontend
flutter pub get
flutter run -d chrome
# ou
flutter run -d windows
```

## Estrutura

```
flown/
  backend/    # Fastify + TypeScript + Prisma (SQLite)
  frontend/   # Flutter + Dart
  docs/
    FLOWN_DOC.md   # documentação de entidades, endpoints e regras de negócio
```

## Licença

MIT — veja [`LICENSE`](LICENSE).
