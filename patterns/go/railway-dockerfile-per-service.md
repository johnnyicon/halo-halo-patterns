---
id: railway-dockerfile-per-service
title: "Railway Services Build From a Dockerfile Per Service, Never Config-as-Code"
type: architecture
status: validated
confidence: high
revision: 1
languages: [go, typescript]
frameworks:
  - name: Railway
    version: "platform and CLI 5.62 inspected 2026-10-15"
    ecosystem: other
  - name: Docker
    version: "BuildKit, distroless static base"
    ecosystem: other
domain: deployment
tags: [railway, docker, dockerfile, nixpacks, railpack, config-as-code, railway-toml, railway-json, monorepo, standard]
introduced: "2026-10-15"
last_verified: "2026-10-15"
review_by: "2027-01-15"
maintainers: []
sanitized: true
related: []
notes: "The default standard for every app on Railway. Decided 2026-10-15 after one API service was found building through railway.toml with Nixpacks while its sibling services already used Dockerfiles."
---

# Railway services build from a Dockerfile per service

## Context

Railway can build a service three ways: an automatic builder that guesses
(Nixpacks, now Railpack), a `railway.json` or `railway.toml` file read at deploy
time (Config as Code), or a Dockerfile. Projects drift into a mix: one service
on a Dockerfile, its sibling on Nixpacks steered by `railway.toml`.

Config as Code is deprecated. Railway's documentation (read 2026-10-15): existing
`railway.json` and `railway.toml` files keep working for services that already use
them until **2026-12-01, a hard cutoff**; new services cannot opt in. The named
replacement is project-wide Infrastructure as Code (`.railway/railway.ts`).
Railway's CLI prints the deprecation on every `railway logs` and deploy run from a
directory holding one of those files.

After the cutoff, a service whose build lived in `railway.toml` falls back to the
automatic builder with no build command. In a Go module with more than one
`cmd/` program, the automatic builder cannot know which program is the service,
so the deploy fails or builds the wrong binary.

## Decision

Every service builds from its own Dockerfile, committed beside the code. Railway's
service settings only point at it and name the health check. No `railway.json` or
`railway.toml`.

| Concern | Dockerfile per service | Automatic builder (Nixpacks/Railpack) |
|---|---|---|
| Where the recipe lives | In the repository, about 15 reviewable lines | Inferred by Railway at build time |
| Stability | Changes only when the file changes | Changes when Railway changes the builder (Nixpacks was already replaced by Railpack) |
| Several programs in one module | The file names the program | Cannot choose; needs commands in settings anyway |
| Portability | `docker build` runs anywhere | Railway only |
| Secrets | Not in the image | Nixpacks passed every service variable, secrets included, into the image as build arguments (`SecretsUsedInArgOrEnv` warnings in the build log) |
| Image | A few megabytes on a distroless base | Much larger |
| Cost | One small file per service | Nothing to write |

Why not Infrastructure as Code as the replacement: a whole-project
`railway.ts` deletes every resource it omits, databases included, and
`railway config migrate` run from a monorepo root collects every
`railway.json`/`railway.toml` in the repository, other products' included, into
one file. Adopt IaC deliberately, as a named partial, if at all; it is not needed to
leave Config as Code.

## Usage

### 1. One Dockerfile per service

Naming: `Dockerfile` for the API, `Dockerfile.<service>` for the rest
(`Dockerfile.web`, `Dockerfile.worker`, `Dockerfile.admin`). For a Go service:

```dockerfile
# <app>-api: the Go API. Nothing is passed as a build argument, so no secret
# is baked into the image. Embed zone data in the binary (import _ "time/tzdata").
FROM golang:1.25 AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -buildvcs=false -o app ./cmd/server

FROM gcr.io/distroless/static-debian12
WORKDIR /app
COPY --from=build /app/app .
EXPOSE 8080
CMD ["./app"]
```

A web wrapper that embeds a built SPA copies the committed `static/dist` the same
way; the frontend is built and committed before deploy, so the image stays a pure
Go build.

### 2. Service settings point at it

Per service, per environment (a Railway settings change; staging first):

- **Dockerfile path**: `Dockerfile` / `Dockerfile.<service>` (relative to the
  uploaded root). A `RAILWAY_DOCKERFILE_PATH` variable also works; prefer the
  setting so it is visible where the other settings are.
- **Health check**: `/health`, timeout 30 seconds.
- **Watch patterns**: only for services deployed from a connected GitHub branch;
  they do nothing for CLI deploys.
- **Root directory**: only for GitHub-connected services in a monorepo. For CLI
  deploys use `--path-as-root` (below) instead.

Then delete `railway.json`/`railway.toml` in a commit and deploy staging from that
commit. The build log must say `load build definition from Dockerfile...`, not
Nixpacks or Railpack.

### 3. Deploy only what is committed

From a monorepo, `railway up` indexes from the git root unless told otherwise
(observed: a 630 MB upload, then an IO error on a broken symlink elsewhere in the
repository). With CLI 5.62 or later:

```bash
railway up . --path-as-root -p <project> -e <environment> -s <service> --ci
```

run from the service's directory makes that directory the upload root (a few MB).
`--path-as-root` uploads the working tree, uncommitted files included, so deploy
from a clean checkout of the commit (`git worktree add --detach <dir> <sha>`), not
from a developer's tree.

Keep a `.railwayignore` in the service directory, with **anchored** entries:

```text
/frontend/node_modules
/frontend/dist
/frontend/e2e
/dist
/.env
```

An unanchored `dist` also matches `static/dist`, and a web image embedding it then
fails with `pattern all:dist: no matching files found`.

Do not rewrite a repository-root `.railwayignore` that another product owns into
an allowlist for yours; `--path-as-root` makes it unnecessary.

## Tradeoffs

- One more file per service to keep current (Go version, base image).
- The Dockerfile path is now a dashboard setting per environment rather than a
  committed file. Record it in the deploy notes.
- Distroless images have no shell; debug with logs, not `railway ssh`.

## Verification checklist

- [ ] Every service has a committed Dockerfile; no `railway.json`/`railway.toml`
      remains in the service's directory or on the branch Railway deploys.
- [ ] Each service's settings name its Dockerfile path and `/health`.
- [ ] Staging deploy log shows `load build definition from Dockerfile...`.
- [ ] `/health` and `/ready` answer 200; the served bundle matches the committed one.
- [ ] `railway logs` no longer prints the Config as Code deprecation.
- [ ] No `SecretsUsedInArgOrEnv` warnings in the build log.
- [ ] Production repeated after its own approval.

## Evidence limits

Verified on one Go API and one Go web wrapper (staging and production,
2026-10-15) and against two other portfolios already on Dockerfiles. The
deprecation date and wording come from Railway's documentation on that date;
re-read it before relying on the cutoff.
