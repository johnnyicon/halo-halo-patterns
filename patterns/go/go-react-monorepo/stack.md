---
id: go-react-monorepo-stack
title: "Go + React Monorepo: The Default Stack"
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
tags: [stack, go, react, vite, tanstack, tailwind, postgres, sqlc, sentry, railway, monorepo]
introduced: "2026-10-15"
last_verified: "2026-10-15"
review_by: "2027-01-15"
maintainers: []
sanitized: true
related: [go-react-monorepo-layout, go-react-monorepo-operations, go-react-monorepo-scaffold, go-react-monorepo-database-hosting]
notes: "Moved from the go-react-monorepo-template skill's references on 2026-10-15; this is now the canonical copy and the skill points here."
---

# Stack Reference

## Active Stack

Use this stack unless the user explicitly changes it:

- Monorepo with Go workspace and PNPM workspace.
- Go API, worker, and optional web wrapper.
- Echo v4 for HTTP routing if matching the reference template exactly.
- PostgreSQL as the canonical database.
- Neon Postgres as the preferred branchable managed database.
- Railway Postgres as an acceptable database when using Railway-hosted app
  services.
- `pgx/v5` for Postgres access.
- `sqlc` for typed Go queries.
- SQL migrations in `db/migrations`.
- Atlas-style migration workflow with explicit local, staging, and production
  environments.
- React + Vite + TypeScript frontend.
- TanStack Router for typed app routing.
- TanStack Query for server state and caching.
- TanStack Table for data-heavy tables when needed.
- Tailwind CSS v4 using `@tailwindcss/vite`.
- Lucide icons.
- shadcn/ui local component source with semantic CSS variables.
- Radix primitives beneath shadcn components where appropriate.
- A checked-in design-system control document defining color, typography,
  spacing, shape, motion, responsive behavior, and component usage.
- Zod for frontend schema validation.
- MSW for frontend request mocks.
- Vitest and Testing Library for frontend tests.
- Playwright for browser and visual regression checks.
- Sentry React and Sentry Go for error telemetry.
- Sentry Vite plugin for production source-map upload.
- Railway deployment, with service names like `{app}-api`, `{app}-web`,
  `{app}-worker`.
- Anito service definitions for local process management when available.
- Tauri desktop and mobile apps later as API clients, not separate schedulers or
  separate backend domains.

## Explicit Non-Stack

Do not use these by default:

- Nuxt.
- Supabase auth, storage, realtime, edge functions, or RLS-dependent app logic.
- A Supabase-first backend model.
- Microservices for v0/v1.
- Client-owned scheduling logic.
- Direct production deploys or production migrations without explicit approval.

## Observed Reference Template Versions

These versions were verified in the active reference implementation on
2026-09-04 and are useful when matching that application exactly:

- Go 1.25.
- Echo v4.15.4.
- `pgx/v5`.
- `sqlc` with `sql_package: pgx/v5`.
- React 19.2.
- Vite 7.1.
- TypeScript 5.9.
- `@tanstack/react-router` 1.130.
- `@tanstack/react-query` 5.90.
- `@tanstack/react-table` 8.21.
- Tailwind CSS 4.1 with `@tailwindcss/vite`.
- shadcn/ui `new-york` style with CSS variables and Lucide icons.
- Radix Dialog, Dropdown Menu, Popover, Slot, and Tooltip primitives.
- Vitest, Testing Library, MSW, and Playwright.

Use current mutually compatible versions for new greenfield projects unless
the user asks to pin to the observed reference template versions.

## Backend Modules

Common backend module shape:

- `internal/config`
- `internal/auth`
- `internal/handler`
- `internal/middleware`
- `internal/store`
- `internal/observability`
- `internal/jobs`
- `internal/integrations`
- `internal/scheduler`
- `internal/ai`
- `internal/packagekit`

Add domain-specific modules only when they own real behavior.

## Frontend Modules

Common frontend module shape:

- `src/router.tsx`
- `src/pages`
- `src/components`
- `src/components/ui`
- `src/hooks`
- `src/lib`
- `src/contexts`
- `src/mocks`
- `src/test`

Use dense operational application UI for dashboards and tools. Do not start
with marketing-page composition unless the user requests a public site.

## Design-System Default

- Run a design-system pass before implementing feature screens.
- Store reusable values as semantic CSS variables consumed by Tailwind.
- Initialize shadcn/ui once, then commit and customize the generated component
  source. It is not a black-box dependency.
- Use one Lucide icon language and accessible text labels for navigation.
- Design mobile-first and adapt primary navigation from a labeled bottom bar on
  phones to a sidebar on large screens.
- Verify 375, 768, 1024, and 1440 pixel widths, visible focus, 4.5:1 normal-text
  contrast, 44-pixel touch targets, and reduced-motion behavior.
