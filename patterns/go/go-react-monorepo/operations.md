---
id: go-react-monorepo-operations
title: "Go + React Monorepo: Operations (Database, Railway, Sentry, Local Dev, Verification)"
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
tags: [operations, railway, dockerfile, neon, postgres, sentry, local-dev, verification]
introduced: "2026-10-15"
last_verified: "2026-10-15"
review_by: "2027-01-15"
maintainers: []
sanitized: true
related: [go-react-monorepo-stack, go-react-monorepo-layout, go-react-monorepo-scaffold, go-react-monorepo-database-hosting, railway-dockerfile-per-service]
notes: "Moved from the go-react-monorepo-template skill's references on 2026-10-15; this is now the canonical copy and the skill points here."
---

# Operations Reference

## Database

Use an isolated local PostgreSQL database as the default development target.
Give development, test, and UAT databases distinct names; never run fixtures or
destructive migrations against a personal or production database. Keep the
connection string in local environment configuration, not the repository.

Use Neon Postgres for branchable managed Postgres when staging/prod branch
workflow matters. Use Railway Postgres when it is more useful to keep app and
database inside Railway for early deployment.

Do not make that choice on feel. `database-hosting.md` has the cost
model from real billing on this stack: Neon bills awake time and Railway is
always-on, so the decision turns on how many hours a day the database is
genuinely awake, and the crossover is arithmetic. Read it before choosing a
host, before blaming one for a bill, and before co-locating services — an app
and database in different regions pay ~60ms per round trip.

Migration rules:

- Keep schema in SQL.
- Keep migrations in `db/migrations` as up/down SQL files.
- Use Atlas-style environments for `local`, `staging`, and `prod`.
- Production migrations require explicit human approval.
- Never run production migrations from a generic `DATABASE_URL` by accident.
  Use an explicit production variable such as `PROD_DATABASE_URL`.

For document retrieval, start with PostgreSQL full-text search plus structured
filters and provenance. Add pgvector only when semantic retrieval has a tested
need. Keep chunks linked to source spans, apply visibility filters before
retrieval, and do not send sensitive content to an external embedding provider
without an explicit privacy decision.

## Sentry

Use Sentry as the default error and telemetry surface:

- Frontend: `@sentry/react`.
- Frontend build: `@sentry/vite-plugin`.
- Backend: `github.com/getsentry/sentry-go` and framework integration where
  available.
- Use release names from git SHA or deployment ID.
- Generate hidden source maps only when upload is enabled.
- Upload source maps only in production builds with explicit Sentry credentials.
- Keep Sentry auth tokens outside the repo.
- Disable Sentry plugin telemetry if the project does not want build telemetry.

Use the `sentry-observability` skill for deeper Sentry audits, dashboards,
release/source-map troubleshooting, or token handling.

## Deployment

Use app-scoped services and production branches:

- Branch pattern: `{app}/production`.
- Service pattern: `{app}-api`, `{app}-web`, `{app}-worker`.
- Keep `main` free for active development and documentation churn.
- Deploy intentionally by pushing to the app production branch.

Railway is the default early deployment target. Use separate services when
API/web/worker need separate lifecycle, resources, or environment variables.

**Every service builds from its own Dockerfile. This is the standard** (decided
2026-10-15; Halo-Halo pattern `railway-dockerfile-per-service`):

- One committed Dockerfile per service: `Dockerfile` for the API,
  `Dockerfile.<service>` for the rest. Static Go binary on a distroless base; no
  build arguments, so no secret is baked into the image.
- Railway's service settings only point at it: Dockerfile path and a `/health`
  check (30 seconds). Staging first; a settings change needs the owner's yes.
- No `railway.json` or `railway.toml`. Railway's Config as Code is deprecated and
  stops being read on 2026-12-01; the automatic builders (Nixpacks, Railpack)
  guess, and cannot pick between several `cmd/` programs in one module.
- CLI deploys: `railway up . --path-as-root -s <service> -e <env> --ci` from the
  service directory, from a clean checkout of the commit (`--path-as-root` uploads
  the working tree as it is). Keep an anchored `.railwayignore` there
  (`/dist`, not `dist`, or `static/dist` is dropped).

## Local Dev

Recommended local setup:

- API process on `:8080` or app-specific port.
- Frontend Vite process on `:5173` or app-specific port.
- Worker only when background jobs are needed.
- `.env.example` documents required variables without secrets.
- Anito definitions can manage API/frontend/worker processes when available.
- Procfile or Makefile targets are useful for simple process/test commands.

## Verification

Minimum verification for scaffold and feature work:

- `go test ./...`
- race tests for risky backend changes when practical.
- `sqlc generate`
- migration status/apply against local DB.
- frontend typecheck/build.
- `vitest run`
- Playwright smoke test and screenshots for UI work.
- Sentry source-map upload only in explicit production build checks.
