---
id: go-react-monorepo-scaffold
title: "Go + React Monorepo: Scaffolding a New App"
type: architecture
status: validated
confidence: high
revision: 1
languages: [go, typescript]
frameworks:
  - name: Go
    version: "1.25"
    ecosystem: go
  - name: React
    version: "18"
    ecosystem: npm
domain: deployment
tags: [scaffold, template, migrations, sqlc, ci, docker, railway]
introduced: "2026-10-15"
last_verified: "2026-10-15"
review_by: "2027-01-15"
maintainers: []
sanitized: true
related: [go-react-monorepo-stack, go-react-monorepo-layout, go-react-monorepo-operations, go-react-monorepo-database-hosting, railway-dockerfile-per-service]
notes: "Moved from the go-react-monorepo-template skill's references on 2026-10-15; this is now the canonical copy and the skill points here."
---

# Scaffold Reference

Use this as a starting point, not a blind script. Inspect existing files first
and adapt module names, ports, and package names to the target repo.

## Initial Folders

```sh
app="<app>"
mkdir -p \
  "apps/$app/cmd/server" \
  "apps/$app/cmd/web" \
  "apps/$app/cmd/worker" \
  "apps/$app/cmd/dev" \
  "apps/$app/frontend" \
  "apps/$app/internal/config" \
  "apps/$app/internal/handler" \
  "apps/$app/internal/middleware" \
  "apps/$app/internal/store/queries" \
  "apps/$app/internal/observability" \
  "apps/$app/internal/jobs" \
  "apps/$app/db/migrations" \
  "apps/$app/static" \
  "pkg/domain" \
  "pkg/scheduler" \
  "pkg/packagekit"
```

## Go Workspace

```sh
go work init "./apps/$app"
cd "apps/$app"
go mod init "github.com/<owner>/<repo>/apps/$app"
go get \
  github.com/labstack/echo/v4 \
  github.com/jackc/pgx/v5 \
  github.com/go-playground/validator/v10 \
  github.com/joho/godotenv \
  github.com/getsentry/sentry-go \
  github.com/getsentry/sentry-go/echo \
  golang.org/x/crypto
```

Use Echo when matching the reference template. Use chi only when the user
explicitly prefers a stdlib-shaped router.

## Frontend Workspace

At repo root:

```yaml
# pnpm-workspace.yaml
packages:
  - "apps/*/frontend"
  - "packages/*"
```

Inside `apps/<app>`:

```sh
pnpm create vite frontend --template react-ts
cd frontend
pnpm add \
  @tanstack/react-router \
  @tanstack/react-query \
  @tanstack/react-table \
  @sentry/react \
  lucide-react \
  sonner \
  zod \
  clsx \
  tailwind-merge \
  class-variance-authority
pnpm add -D \
  @tailwindcss/vite \
  tailwindcss \
  @sentry/vite-plugin \
  @tanstack/router-devtools \
  vitest \
  @vitest/coverage-v8 \
  @testing-library/react \
  @testing-library/jest-dom \
  @testing-library/user-event \
  happy-dom \
  msw \
  @playwright/test
```

Wire Tailwind v4 through `@tailwindcss/vite`, not PostCSS/Tailwind v3 config.

Initialize shadcn/ui after the Vite aliases and Tailwind entry point exist:

```sh
pnpm dlx shadcn@latest init
pnpm dlx shadcn@latest add \
  alert badge button card command dialog sheet skeleton tabs tooltip
```

Use the `new-york` style when matching the reference template. Keep `rsc: false`, `tsx: true`,
CSS variables enabled, and Lucide as the icon library. Add only the components
the product needs, then customize their checked-in source to the project's
design system.

## Database Files

Add:

- `db/schema.sql`
- `db/migrations/*.up.sql`
- `db/migrations/*.down.sql`
- `sqlc.yaml`
- `atlas.hcl`

`sqlc.yaml` should use:

```yaml
version: "2"
sql:
  - engine: "postgresql"
    queries: "internal/store/queries/"
    schema: "db/schema.sql"
    gen:
      go:
        package: "store"
        out: "internal/store"
        emit_json_tags: true
        emit_db_tags: true
        sql_package: "pgx/v5"
```

## Environment Names

Start with these names unless the project already has conventions:

```text
APP_ENV
PORT
DATABASE_URL
STAGING_DATABASE_URL
PROD_DATABASE_URL
ATLAS_DEV_DATABASE_URL
SESSION_SECRET
CORS_ALLOWED_ORIGINS
SENTRY_DSN
SENTRY_ENVIRONMENT
SENTRY_RELEASE
SENTRY_DIST
SENTRY_ORG
SENTRY_PROJECT
SENTRY_AUTH_TOKEN
SENTRY_UPLOAD_SOURCEMAPS
RAILWAY_GIT_COMMIT_SHA
RAILWAY_DEPLOYMENT_ID
```

Keep Sentry auth tokens, database URLs, OAuth secrets, and API keys outside the
repo. `.env.example` should document names but never values.

## Auth Default

Default to server-side sessions for a commercializable web app. A private
single-user local mode is acceptable for a prototype. Do not use Supabase Auth.

Minimum session model:

- users table
- sessions table with hashed token
- httpOnly, Secure, SameSite cookie
- server-side session lookup on API requests
- logout deletes/revokes session

Add OAuth only for external integrations such as Google Calendar or ClickUp.

## API Style

Use `/api/v1` JSON routes. Keep provider schemas out of public API contracts.

Recommended conventions:

- command-style POST routes for operations with side effects
- idempotency keys for external writes and retries
- structured JSON errors with stable codes
- validation at handler boundaries
- audit events for meaningful mutations
- context cancellation/timeouts for external calls
- no direct browser access to provider tokens

## CI Starter

Minimum CI jobs:

- Go tests: `go test ./...`
- sqlc generation check: `sqlc generate` plus clean diff check
- frontend typecheck/build
- frontend tests: `vitest run`
- Playwright smoke tests for UI-heavy apps
- optional migration lint/status against local Postgres

Do not run production migrations in CI unless the deployment process has an
explicit human gate.

## Docker And Railway Starter

Every service builds from its own Dockerfile; Railway settings point at it
(Dockerfile path, `/health`). Never add `railway.json` or `railway.toml`: Config
as Code is deprecated and stops being read on 2026-12-01. See
`operations.md` and the Halo-Halo pattern
`railway-dockerfile-per-service`.

- `Dockerfile` for API.
- `Dockerfile.web` for web wrapper and embedded frontend.
- `Dockerfile.worker` for background jobs if needed.

Railway service names:

```text
<app>-api
<app>-web
<app>-worker
```

Production branch:

```text
<app>/production
```

Keep `main` available for active development and docs. Deploy intentionally by
pushing to the app production branch.
