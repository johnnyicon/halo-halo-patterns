---
id: ts-nextjs-stale-ui-after-mutation
title: Next.js UI stays stale after mutation due to cache/index invalidation gaps
type: troubleshooting
status: validated
confidence: medium
revision: 1

languages: [TypeScript]
frameworks:
  - ecosystem: npm
    name: next
    version: ">=14 <16"

dependencies:
  - ecosystem: npm
    name: react
    version: ">=18 <20"

runtime: ["Vercel", "Node"]
domain: indexing
tags: ["cache", "revalidation", "stale-ui", "indexing"]

introduced: 2026-01-08
last_verified: 2026-01-08
review_by: 2026-04-08

maintainers: ["@team-patterns"]
deprecated_date: null
superseded_by: null
related: []
sanitized: true
migration_note: null
notes: "Generalized from multiple projects."
---

## Context
Apps that mutate backend data but rely on an indexing/caching layer for reads.

## Symptoms
- UI shows old values after a successful mutation
- Refresh fixes it only after a delay

## Root cause
Invalidation path is missing or delayed between mutation and the read model.

## Fix
1. Ensure mutations publish an invalidation signal.
2. Revalidate cache/route after mutation.
3. Add a temporary “read-your-writes” bypass if indexing is async.

## Verification checklist
- [ ] Reproduce before fix
- [ ] Confirm UI updates immediately after mutation
- [ ] Add a regression check

## Tradeoffs
More invalidations reduces cache hit-rate.
