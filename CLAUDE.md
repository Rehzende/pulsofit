# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Estrutura do projeto

```
personal_ai/
├── backend/          # FastAPI + SQLAlchemy async + PostgreSQL
├── frontend/         # Next.js 13+ App Router (Vercel)
├── mobile_app/       # Flutter + Provider
└── BACKLOG.md        # Product backlog priorizado
```

---

## Backend (FastAPI)

### Rodar localmente

```bash
cd backend
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

O `.env` precisa ter:
```
POSTGRES_SERVER=localhost
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=trainer_iot
POSTGRES_PORT=5432
ANTHROPIC_API_KEY=sk-ant-...
SECRET_KEY=...
```

### Migrations (Alembic)

```bash
# Criar nova migration após alterar um model
alembic revision --autogenerate -m "descricao_da_mudanca"

# Aplicar localmente
alembic upgrade head

# Ver revisão atual
alembic current

# Aplicar em produção (Railway) manualmente
DATABASE_URL="postgresql://postgres:<senha>@tramway.proxy.rlwy.net:59247/railway" \
  alembic upgrade head
# Obter URL: railway variables --service Postgres | grep DATABASE_PUBLIC_URL
```

### Deploy do backend

Backend no Railway, serviço `web`. Push para `main` → deploy automático.

```bash
railway status --json                          # ver serviços
railway variables --service web               # variáveis do backend
railway variables --service web set CHAVE=valor
railway logs --service web                    # logs em tempo real
```

**URL de produção:** `https://web-production-06662.up.railway.app`

---

## Mobile (Flutter)

```bash
cd mobile_app
flutter pub get
flutter run                    # emulador conectado
flutter run -d <device_id>     # device específico
flutter devices                # listar devices

# Build
flutter build apk --release
flutter build appbundle --release  # Google Play
# Output: build/app/outputs/flutter-apk/app-release.apk
```

A URL do backend está em `mobile_app/lib/core/constants.dart`. Para dev local, trocar para o IP da máquina (`http://192.168.x.x:8000`).

---

## Frontend (Next.js)

```bash
cd frontend
npm install
npm run dev    # http://localhost:3000
npm run build
npm run lint
```

Frontend na Vercel. Push para `main` → deploy automático.

---

## Fluxo de desenvolvimento

1. Alterar código no backend
2. Se adicionou coluna no model: `alembic revision --autogenerate -m "..."`
3. Push para `main` → Railway faz deploy + roda `alembic upgrade head` automaticamente

---

## Arquitetura do Backend

**Rotas** centralizadas em `backend/app/api/api.py`. Prefixo `/api/v1`. Cada domínio tem seu próprio router em `backend/app/api/endpoints/`.

**Auth & Dependências** (`backend/app/api/deps.py`):
- `get_current_user()` valida JWT e retorna o `User` com `trainer_profile` já eager-loaded (evita erros de greenlet do asyncio)
- JWT: access token (15-30min) + refresh token (7 dias)

**Database**:
- Async engine com `asyncpg`. URLs **sempre** com `postgresql+asyncpg://`
- Sessões via `get_db()` (Depends) — nunca instanciar `AsyncSession` diretamente nos endpoints
- `DATABASE_PUBLIC_URL` do Railway = conexão externa; `DATABASE_URL` = interna entre serviços

**CRÍTICO — DateTime**:
- Colunas `DateTime` no banco = `TIMESTAMP WITHOUT TIME ZONE`
- **Sempre usar `datetime.utcnow()`**, NUNCA `datetime.now(timezone.utc)` — asyncpg rejeita objetos timezone-aware

**Roles**: `SUPER_ADMIN`, `TRAINER`, `STUDENT`. Trainers têm `TrainerProfile` separado com dados de marca/marketplace.

**WebSocket**: Singleton `ConnectionManager` em `backend/app/websockets/manager.py`. Suporta múltiplos dispositivos por usuário (Dict[user_id] → List[WebSocket]).

**IA**: Claude Sonnet (`claude-sonnet-4-6`) via `anthropic` SDK. Chamadas síncronas wrapped em `asyncio.to_thread`.

---

## Arquitetura do Frontend

**API Client**: Singleton Axios em `frontend/src/lib/api.ts` com interceptors para:
- Injeção automática do Bearer token (localStorage)
- Refresh automático no 401 (POST `/refresh-token`)
- Redirect para `/login` se refresh falhar

**Layouts por role**: `StudentLayout` e `TrainerLayout` com `BottomNavigation` diferente. Admin usa layout próprio em `/admin/`.

**UI**: shadcn/ui (Radix UI) + Tailwind CSS 4 + Framer Motion. Stack: React 19, Next.js 16, TypeScript 5.

---

## Arquitetura Mobile (Flutter)

**State Management**: 3 providers principais:
- `AuthProvider` — tokens, dados do user, flags (anamnesis, AI terms, trainer brand)
- `WorkoutSessionProvider` — estado da sessão ao vivo
- `BluetoothController` — pareamento com dispositivos HR via BLE

**Auto-triggers** em `MainNavigationScreen.initState()`:
- Students sem anamnese → abre `OnboardingQuizScreen`
- Trainers sem `brand_name` → abre `TrainerSetupWizardScreen`

**HTTP**: Dio com interceptors de token. Armazenamento seguro via `flutter_secure_storage`.

---

## Notas importantes

- Migrations rodam **automaticamente** no deploy via `backend/railway.json`
- O `ANTHROPIC_API_KEY` já está configurado no Railway (serviço `web`)
- Não há testes automatizados configurados no projeto atualmente

<!-- rtk-instructions v2 -->
# RTK (Rust Token Killer) - Token-Optimized Commands

## Golden Rule

**Always prefix commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

## RTK Commands by Workflow

### Build & Compile (80-90% savings)
```bash
rtk cargo build         # Cargo build output
rtk cargo check         # Cargo check output
rtk cargo clippy        # Clippy warnings grouped by file (80%)
rtk tsc                 # TypeScript errors grouped by file/code (83%)
rtk lint                # ESLint/Biome violations grouped (84%)
rtk prettier --check    # Files needing format only (70%)
rtk next build          # Next.js build with route metrics (87%)
```

### Test (90-99% savings)
```bash
rtk cargo test          # Cargo test failures only (90%)
rtk vitest run          # Vitest failures only (99.5%)
rtk playwright test     # Playwright failures only (94%)
rtk test <cmd>          # Generic test wrapper - failures only
```

### Git (59-80% savings)
```bash
rtk git status          # Compact status
rtk git log             # Compact log (works with all git flags)
rtk git diff            # Compact diff (80%)
rtk git show            # Compact show (80%)
rtk git add             # Ultra-compact confirmations (59%)
rtk git commit          # Ultra-compact confirmations (59%)
rtk git push            # Ultra-compact confirmations
rtk git pull            # Ultra-compact confirmations
rtk git branch          # Compact branch list
rtk git fetch           # Compact fetch
rtk git stash           # Compact stash
rtk git worktree        # Compact worktree
```

Note: Git passthrough works for ALL subcommands, even those not explicitly listed.

### GitHub (26-87% savings)
```bash
rtk gh pr view <num>    # Compact PR view (87%)
rtk gh pr checks        # Compact PR checks (79%)
rtk gh run list         # Compact workflow runs (82%)
rtk gh issue list       # Compact issue list (80%)
rtk gh api              # Compact API responses (26%)
```

### JavaScript/TypeScript Tooling (70-90% savings)
```bash
rtk pnpm list           # Compact dependency tree (70%)
rtk pnpm outdated       # Compact outdated packages (80%)
rtk pnpm install        # Compact install output (90%)
rtk npm run <script>    # Compact npm script output
rtk npx <cmd>           # Compact npx command output
rtk prisma              # Prisma without ASCII art (88%)
```

### Files & Search (60-75% savings)
```bash
rtk ls <path>           # Tree format, compact (65%)
rtk read <file>         # Code reading with filtering (60%)
rtk grep <pattern>      # Search grouped by file (75%)
rtk find <pattern>      # Find grouped by directory (70%)
```

### Analysis & Debug (70-90% savings)
```bash
rtk err <cmd>           # Filter errors only from any command
rtk log <file>          # Deduplicated logs with counts
rtk json <file>         # JSON structure without values
rtk deps                # Dependency overview
rtk env                 # Environment variables compact
rtk summary <cmd>       # Smart summary of command output
rtk diff                # Ultra-compact diffs
```

### Infrastructure (85% savings)
```bash
rtk docker ps           # Compact container list
rtk docker images       # Compact image list
rtk docker logs <c>     # Deduplicated logs
rtk kubectl get         # Compact resource list
rtk kubectl logs        # Deduplicated pod logs
```

### Network (65-70% savings)
```bash
rtk curl <url>          # Compact HTTP responses (70%)
rtk wget <url>          # Compact download output (65%)
```

### Meta Commands
```bash
rtk gain                # View token savings statistics
rtk gain --history      # View command history with savings
rtk discover            # Analyze Claude Code sessions for missed RTK usage
rtk proxy <cmd>         # Run command without filtering (for debugging)
rtk init                # Add RTK instructions to CLAUDE.md
rtk init --global       # Add RTK to ~/.claude/CLAUDE.md
```

## Token Savings Overview

| Category | Commands | Typical Savings |
|----------|----------|-----------------|
| Tests | vitest, playwright, cargo test | 90-99% |
| Build | next, tsc, lint, prettier | 70-87% |
| Git | status, log, diff, add, commit | 59-80% |
| GitHub | gh pr, gh run, gh issue | 26-87% |
| Package Managers | pnpm, npm, npx | 70-90% |
| Files | ls, read, grep, find | 60-75% |
| Infrastructure | docker, kubectl | 85% |
| Network | curl, wget | 65-70% |

Overall average: **60-90% token reduction** on common development operations.
<!-- /rtk-instructions -->