---
id: go-react-monorepo-layout
title: "Go + React Monorepo: Repository Layout"
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
domain: api-design
tags: [layout, monorepo, go-workspace, pnpm-workspace, structure]
introduced: "2026-10-15"
last_verified: "2026-10-15"
review_by: "2027-01-15"
maintainers: []
sanitized: true
related: [go-react-monorepo-stack, go-react-monorepo-operations, go-react-monorepo-scaffold, go-react-monorepo-database-hosting]
notes: "Moved from the go-react-monorepo-template skill's references on 2026-10-15; this is now the canonical copy and the skill points here."
---

# Repo Layout Reference

## Default Monorepo Shape

```text
go.work
pnpm-workspace.yaml
apps/
  <app>/
    go.mod
    cmd/
      server/
      web/
      worker/
      dev/
    frontend/
      package.json
      vite.config.ts
      vite.config.ssr.ts
      src/
    internal/
      config/
      handler/
      middleware/
      store/
      observability/
    db/
      schema.sql
      migrations/
    static/
    .anito/
pkg/
  domain/
  scheduler/
  packagekit/
```

## Command Responsibilities

- `cmd/server`: API server. Own routes, auth, validation, API middleware, and
  server-side commands.
- `cmd/worker`: background jobs, integration sync, retries, schedule
  recomputation, and webhook reconciliation.
- `cmd/web`: optional delivery server for compiled frontend assets, metadata
  injection, SSR sidecar, or public pages.
- `cmd/dev`: optional local process helper if Anito or a Procfile is not enough.

## Frontend Delivery

Start simple:

1. Vite builds the browser app.
2. Go API serves JSON.
3. Vite dev server proxies `/api` in development.
4. Add a Go web wrapper when deployment needs one binary/service, public
   metadata injection, SSR, or embedded assets.

For authenticated operational dashboards, SSR is not a v0 blocker. Use SSR only
when share pages, crawler-readable public pages, or rich link previews matter.

## Future Clients

Future Tauri and mobile clients should:

- Reuse the API and scheduling contracts.
- Queue offline commands with idempotency keys.
- Avoid embedding independent scheduling engines.
- Treat server state as canonical.
