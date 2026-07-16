# Flown — Documentação do Projeto

> Nome: **Flown**  
> Versão do documento: 2.0  
> Status: Em desenvolvimento

---

## Sumário

- [1. Visão Geral](#1-visão-geral)
- [2. Plataformas](#2-plataformas)
- [3. Stack Tecnológico](#3-stack-tecnológico)
- [4. Arquitetura](#4-arquitetura)
- [5. Autenticação](#5-autenticação)
- [6. Banco de Dados — Estratégia Offline/Online](#6-banco-de-dados--estratégia-offlineonline)
- [7. Entidades](#7-entidades)
  - [7.1 User](#71-user)
  - [7.2 RefreshToken](#72-refreshtoken)
  - [7.3 ProjectType](#73-projecttype)
  - [7.4 Project](#74-project)
  - [7.5 Task](#75-task)
  - [7.6 Note](#76-note)
  - [7.7 FocusSession](#77-focussession)
- [8. Focus Mode](#8-focus-mode)
- [9. Dashboard de Produtividade](#9-dashboard-de-produtividade)
- [10. Lixeira](#10-lixeira)
- [11. Busca Global](#11-busca-global)
- [12. Drag-and-Drop](#12-drag-and-drop)
- [13. Endpoints](#13-endpoints)
- [14. Decisões Técnicas Pendentes](#14-decisões-técnicas-pendentes)
- [15. Ordem de Implementação Sugerida](#15-ordem-de-implementação-sugerida)


## 1. Visão Geral

Flown é um aplicativo de **gerenciamento de tarefas e gestão de tempo**, inicialmente desenvolvido para uso pessoal, mas arquitetado para suportar múltiplos usuários futuramente sem reescrita significativa.

---

## 2. Plataformas

| Plataforma | Tecnologia | Status |
|---|---|---|
| Desktop (Windows/Linux/macOS) | Flutter | Prioridade inicial |
| Web | Flutter Web | Segunda etapa |
| Mobile | Flutter (possível) | Não planejado ainda |

O mesmo código Flutter servirá para Desktop e Web — não haverá codebase separada por plataforma.

---

## 3. Stack Tecnológico

### Backend
| Camada | Tecnologia |
|---|---|
| Framework | Fastify |
| Linguagem | TypeScript |
| ORM | Prisma |
| Banco offline | SQLite |
| Banco online | PostgreSQL (Railway) |
| Validação | Joi |
| Autenticação | JWT (access token 15min + refresh token 30 dias) + bcrypt |

### Frontend
| Camada | Tecnologia |
|---|---|
| Framework | Flutter + Dart |
| Gerenciamento de estado | Riverpod |
| Estilização | ThemeData customizado (baseado no design original em Tailwind) |
| Temas | Light (pronto) + Dark (a implementar) |
| Internacionalização | i18n — pt-BR e en-US |

### Infraestrutura
| Serviço | Plataforma |
|---|---|
| Backend + PostgreSQL | Railway |
| Frontend Web | Vercel (Flutter Web build estático) |
| Repositório | Git (monorepo) |

---

## 4. Arquitetura

### Monorepo
```
flown/
  backend/
  frontend/
  docs/
    FLOWN_DOC.md
```

### Backend — Arquitetura em Camadas
```
Request → Route → Middleware (auth) → Controller → Service → Repository → Prisma → DB
```

```
backend/src/
  routes/
  controllers/
  services/
  repositories/
  schemas/          # Joi schemas (CreateX, UpdateX, XResponse)
  middlewares/      # auth JWT, error handler
  utils/            # jwt.ts, constants.ts
  prisma/
    schema.prisma
```

### Frontend — Feature-based (Nível 2)
```
frontend/lib/
  features/
    tasks/
      screens/
      widgets/
      providers/
    projects/
    notes/
    focus/
    auth/
    dashboard/
    search/
    trash/
  core/
    services/       # HTTP client, API base
    theme/          # ThemeData light/dark, cores
    widgets/        # componentes compartilhados
    l10n/           # arquivos de internacionalização (pt-BR, en-US)
  main.dart
```

---

## 5. Autenticação

### Access Token + Refresh Token
- **Access token**: expira em 15 minutos. Usado em todas as requisições autenticadas.
- **Refresh token**: expira em 30 dias. Guardado de forma segura no cliente. Usado exclusivamente para gerar um novo access token sem precisar de login.

### Fluxo
```
Login → servidor retorna { accessToken, refreshToken }
Requisição normal → Authorization: Bearer <accessToken>
Access token expirado → cliente chama POST /auth/refresh com o refreshToken
Servidor valida refreshToken → devolve novo accessToken
RefreshToken expirado → usuário precisa fazer login novamente
```

### Regras
- Senha armazenada como hash (bcrypt, salt rounds: 10). Nunca em texto puro.
- `userId` nunca vem do body das requisições — sempre extraído do token JWT pelo middleware e injetado em `req.user.id`.
- Troca de senha via endpoint dedicado (`POST /auth/change-password`).
- Controle de registro via variável de ambiente:
  - `ALLOW_REGISTER=true` → qualquer um pode criar conta (padrão em desenvolvimento)
  - `ALLOW_REGISTER=false` → registro bloqueado (produção pessoal)
  - `SKIP_AUTH=true` → pula tela de login completamente (útil em testes locais)

---

## 6. Banco de Dados — Estratégia Offline/Online

### Dois modos de operação
- **Offline**: SQLite local, sem autenticação necessária.
- **Online**: PostgreSQL no Railway, com autenticação JWT obrigatória.

### Estratégia de Sincronização
```
Conectou à internet →
  Para cada registro local:
    - Não existe online → cria online
    - Existe online e local.updatedAt > online.updatedAt → atualiza online
    - Existe online e online.updatedAt > local.updatedAt → atualiza local
    - updatedAt igual → nenhuma ação
```

**Critério de desempate**: o registro com `updatedAt` mais recente sempre prevalece ("last write wins").

> Detalhe de implementação: a camada de sync será um serviço isolado no backend, acionado quando o app detectar conexão disponível. Será detalhado em documento separado na fase de implementação.

---

## 7. Entidades

### 7.1 User
| Campo | Tipo | Notas |
|---|---|---|
| id | String (cuid) | Gerado pelo Prisma |
| name | String | Obrigatório |
| email | String | Único |
| password | String | Hash bcrypt |
| createdAt | DateTime | Automático |
| updatedAt | DateTime | Automático |

**Relações**: possui Tasks, Projects, Notes e FocusSessions.

---

### 7.2 RefreshToken
Armazena refresh tokens no banco para permitir invalidação no logout.

| Campo | Tipo | Notas |
|---|---|---|
| id | String (cuid) | Gerado pelo Prisma |
| token | String | Único, hash do token |
| expiresAt | DateTime | 30 dias a partir da criação |
| createdAt | DateTime | Automático |
| userId | String | FK → User |

> Ao fazer logout, o registro é deletado — invalidando o refresh token sem precisar de blacklist.

---

### 7.3 ProjectType
Tabela no banco — permite adicionar novos tipos de projeto sem alterar código ou rodar migrations.

| Campo | Tipo | Notas |
|---|---|---|
| id | String (cuid) | Gerado pelo Prisma |
| name | String | Único (ex: "software", "pessoal", "estudo") |
| availableStatus | Json | Lista de status disponíveis para tasks desse tipo — Json por compatibilidade SQLite/PostgreSQL |
| projects | Project[] | Relação |

> Seeds iniciais: `software` (Backlog, Todo, In Progress, In Review, Blocked, Done, Cancelled) e `general` (Todo, In Progress, Blocked, Done, Cancelled).

---

### 7.3 Project
| Campo | Tipo | Notas |
|---|---|---|
| id | String (cuid) | Gerado pelo Prisma |
| name | String | Obrigatório |
| description | String? | Nullable |
| color | String | Baseado em ProjectColors |
| isArchived | Boolean | Default: false — projetos arquivados saem da lista principal |
| isDeleted | Boolean | Default: false — soft delete (lixeira) |
| deletedAt | DateTime? | Preenchido ao mover para lixeira |
| order | Int | Para drag-and-drop |
| createdAt | DateTime | Automático |
| updatedAt | DateTime | Automático |
| userId | String | FK → User |
| typeId | String | FK → ProjectType |

**Relações**: possui Tasks e Notes.

---

### 7.4 Task
| Campo | Tipo | Notas |
|---|---|---|
| id | String (cuid) | Gerado pelo Prisma |
| title | String | Obrigatório |
| description | String? | Nullable |
| status | String | Validado contra os status disponíveis no ProjectType |
| priority | Enum | Low, Medium, High |
| dueDate | DateTime? | Nullable |
| progress | Int? | 0–100 |
| estimatedTime | String? | Máx 20 chars |
| tags | Json | Máx 50 chars por tag — Json por compatibilidade SQLite/PostgreSQL |
| checklist | Json? | Array de { text, completed } |
| order | Int | Default: 0 — para drag-and-drop |
| isDeleted | Boolean | Default: false — soft delete (lixeira) |
| deletedAt | DateTime? | Preenchido ao mover para lixeira |
| createdAt | DateTime | Automático |
| updatedAt | DateTime | Automático |
| userId | String | FK → User |
| projectId | String? | FK → Project (nullable — task pode existir sem projeto) |
| parentTaskId | String? | FK → Task (nullable — para subtasks) |

**Subtasks**: uma task pode ter tasks filhas via `parentTaskId`. Subtasks seguem os mesmos campos da task pai. Não há limite de profundidade definido na v1 — recomendado limitar a 1 nível na interface (task → subtask, sem sub-subtask).

---

### 7.5 Note
| Campo | Tipo | Notas |
|---|---|---|
| id | String (cuid) | Gerado pelo Prisma |
| title | String | Obrigatório |
| content | String | Obrigatório |
| tags | Json | Máx 50 chars por tag — Json por compatibilidade SQLite/PostgreSQL |
| isPinned | Boolean | Default: false |
| order | Int | Default: 0 — para drag-and-drop |
| isDeleted | Boolean | Default: false — soft delete (lixeira) |
| deletedAt | DateTime? | Preenchido ao mover para lixeira |
| createdAt | DateTime | Automático |
| updatedAt | DateTime | Automático |
| userId | String | FK → User |
| projectId | String? | FK → Project (nullable — nota pode existir sem projeto) |

---

### 7.6 FocusSession
| Campo | Tipo | Notas |
|---|---|---|
| id | String (cuid) | Gerado pelo Prisma |
| type | Enum | `pomodoro`, `stopwatch` |
| durationSeconds | Int | Obrigatório, mín 1 |
| startedAt | DateTime | Obrigatório |
| completedAt | DateTime? | Nullable — null = sessão em andamento |
| userId | String | FK → User |
| taskId | String? | FK → Task (nullable) |

---

## 8. Focus Mode

Dois modos disponíveis simultaneamente:

### Pomodoro
- Ciclos de foco + pausa curta + pausa longa (após N ciclos).
- **Configuração padrão**: `25min foco / 5min pausa curta / 15min pausa longa / 4 ciclos`.
- Todos os valores configuráveis nas **Settings** do app.
- Cada ciclo de foco concluído gera um registro em `FocusSession` com `type: "pomodoro"`.
- **Notificação nativa desktop** ao fim de cada ciclo (foco e pausa).

### Cronômetro
- Timer livre, sem ciclos.
- Usuário inicia, pausa e encerra manualmente.
- Ao encerrar, gera um registro em `FocusSession` com `type: "stopwatch"` e a duração total.
- **Notificação nativa desktop** opcional ao atingir um tempo configurado.

Em ambos os modos, o usuário pode opcionalmente vincular a sessão a uma Task.

---

## 9. Dashboard de Produtividade

Tela com gráficos baseados nos dados de `FocusSession`. Métricas planejadas:

- Horas focadas por dia (últimos 7/30 dias)
- Horas focadas por task
- Horas focadas por projeto
- Distribuição Pomodoro vs Cronômetro
- Streak de dias com pelo menos uma sessão

> **Exportação (PDF/CSV)**: não implementada na v1, mas o endpoint de dados do dashboard (`GET /dashboard/stats`) deve retornar os dados brutos de forma que uma exportação possa ser adicionada futuramente sem alterar a query.

---

## 10. Lixeira

Tasks, Notas e Projetos deletados vão para a lixeira (soft delete via `isDeleted: true` + `deletedAt`).

- Itens na lixeira não aparecem nas listagens normais.
- O usuário pode **restaurar** (seta `isDeleted` para false, limpa `deletedAt`) ou **deletar permanentemente**.
- Limpeza automática da lixeira: itens com mais de **30 dias** em `deletedAt` são deletados permanentemente (job agendado no backend).
- Ao deletar um Projeto permanentemente, Tasks e Notas vinculadas também são deletadas (cascade).

---

## 11. Busca Global

- Busca unificada por Tasks, Notas e Projetos simultaneamente.
- Filtra por `title`, `description`, `tags` e `content` (notas).
- Retorna resultados agrupados por tipo (Tasks / Notas / Projetos).
- Endpoint: `GET /search?q=termo`
- Itens na lixeira (`isDeleted: true`) não aparecem nos resultados.

---

## 12. Drag-and-Drop

Tasks e Notas possuem campo `order: Int` para reordenação manual.

- Ao reordenar via drag-and-drop no frontend, o app chama `PATCH /tasks/reorder` (ou `/notes/reorder`) com a nova ordem.
- A reordenação é por lista (ex: tasks de um projeto, tasks sem projeto, notas de um projeto, notas soltas).

---

## 13. Endpoints

### Auth
```
POST   /auth/register
POST   /auth/login
POST   /auth/refresh          # troca refreshToken por novo accessToken
POST   /auth/logout           # invalida refreshToken
POST   /auth/change-password  # autenticado
```

### Users
```
GET    /users/me              # autenticado
PATCH  /users/me              # autenticado
```

### Tasks
```
GET    /tasks                 # autenticado
POST   /tasks                 # autenticado
GET    /tasks/:id             # autenticado
PATCH  /tasks/:id             # autenticado
DELETE /tasks/:id             # move para lixeira
POST   /tasks/:id/restore     # restaura da lixeira
DELETE /tasks/:id/permanent   # deleta permanentemente
PATCH  /tasks/reorder         # atualiza ordem (drag-and-drop)
GET    /tasks/:id/subtasks    # lista subtasks de uma task
POST   /tasks/:id/subtasks    # cria subtask
```

### Projects
```
GET    /projects              # autenticado
POST   /projects              # autenticado
GET    /projects/:id          # autenticado
PATCH  /projects/:id          # autenticado
DELETE /projects/:id          # move para lixeira
POST   /projects/:id/restore  # restaura da lixeira
DELETE /projects/:id/permanent
PATCH  /projects/:id/archive  # arquiva projeto
PATCH  /projects/:id/unarchive
GET    /projects/:id/tasks
GET    /projects/:id/notes
```

### Project Types
```
GET    /project-types         # lista tipos disponíveis
POST   /project-types         # cria novo tipo (admin)
```

### Notes
```
GET    /notes                 # autenticado
POST   /notes                 # autenticado
GET    /notes/:id             # autenticado
PATCH  /notes/:id             # autenticado
DELETE /notes/:id             # move para lixeira
POST   /notes/:id/restore     # restaura da lixeira
DELETE /notes/:id/permanent
PATCH  /notes/reorder         # atualiza ordem (drag-and-drop)
```

### Focus Sessions
```
GET    /sessions              # autenticado
POST   /sessions              # autenticado
PATCH  /sessions/:id          # autenticado
POST   /sessions/:id/complete # marca como concluída
DELETE /sessions/:id          # autenticado
```

### Dashboard
```
GET    /dashboard/stats       # retorna dados brutos de produtividade
```

### Search
```
GET    /search?q=termo        # busca global
```

### Trash
```
GET    /trash                 # lista todos os itens na lixeira
DELETE /trash/empty           # esvazia lixeira permanentemente
```

---

## 14. Decisões Técnicas Pendentes

| Decisão | Notas |
|---|---|
| Nome do app | A definir |
| Limite de profundidade de subtasks | Recomendado 1 nível na UI, sem limite no backend |
| Job de limpeza da lixeira | Cron job no Railway ou verificação on-demand |
| Estratégia de sync detalhada | Documento separado na fase de implementação |

---

## 15. Ordem de Implementação Sugerida

1. Setup do monorepo + git init + configurações base (tsconfig, eslint, prisma)
2. `schema.prisma` completo
3. Joi schemas (`/schemas`)
4. Middleware de auth (JWT access + refresh)
5. Repositories (CRUD base por entidade)
6. Services (regras de negócio)
7. Controllers + Routes (ordem: auth → users → project-types → projects → tasks → notes → sessions → dashboard → search → trash)
8. Frontend Flutter (feature por feature, seguindo a mesma ordem)