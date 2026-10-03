---
id: durable-index-jobs-with-idle-workers
title: Durable PostgreSQL Index Jobs with Idle Workers
type: implementation
status: draft
confidence: low
revision: 1
languages: [go, sql]
frameworks:
  - name: PostgreSQL and pgx
    version: "Design reviewed 2026-10-03; not implemented"
    ecosystem: go
domain: concurrency
tags: [postgres, queues, workers, serverless, polling, indexing, cost]
introduced: "2026-10-03"
last_verified: "2026-10-03"
review_by: "2027-01-01"
maintainers: []
sanitized: true
related: []
---

# Durable jobs with workers that can become idle

## Context

A PostgreSQL-backed queue uses short empty-queue polls to find new work. This creates unnecessary queries and can prevent a serverless database from suspending. The database job rows already provide durability; the poll frequency is not what makes the jobs safe.

This is a proposed Go implementation recipe derived from source review, not a production-validated package. See the [hosting and cost research](../../docs/database-hosting-and-idle-workers-2026-10.md).

## Usage

### 1. Commit work before signalling

Persist the job in the same transaction as its associated version where possible. Every enqueue route must be inventoried, including SQL CTEs and direct inserts. After successful commit, send a coalesced wake to a scheduler owned by that application/database instance. Do not enqueue only in memory, signal on rollback, or create a process-global singleton that mixes test pools or tenants.

The wake is an optimization. A crash between commit and signal leaves a recoverable durable job. For multiple replicas, let the writer's local scheduler drain the shared queue; database claims arbitrate concurrency. Writers without a scheduler need an explicit supported wake path or documented bounded reconciliation. Do not assume in-memory channels broadcast to other processes.

### 2. One coordinator, bounded active workers

The coordinator waits on cancellation, a buffered/coalesced wake, the next known retry/lease deadline, or a slow safety timer. It dispatches only up to the configured concurrency. Workers drain claimable jobs using the existing transactional claim/lease protocol. No work means they park; do not leave every worker independently polling.

Use a generation counter or equivalently tested channel/state protocol to avoid losing a wake between the final empty claim and parking. Bound signals during bulk imports rather than creating one goroutine/timer per uploaded document. Keep active concurrency and provider request limits intact.

### 3. Recover retries, leases and missed wakes

Run a reconciliation on process startup. After a failed attempt, schedule the durable `available_at` deadline without waiting for an unrelated upload. On active scans, obtain the next eligible retry/expired-lease deadline and arm a timer. Preserve existing retry limits, fenced completion and immutable data references. After restart, reconstruct deadlines from durable rows.

A slow safety sweep catches committed rows missed by local signals and lease changes made by another process. Proposed starting interval: 15 minutes, with bounded jitter and an explicit maximum. This permits some sleep on a five-minute-suspend service but still costs roughly eight awake hours/day from sweeps alone. An hourly setting is cheaper but allows longer recovery delay. The selected interval is a product reliability/cost decision.

Use bounded exponential backoff with jitter for unavailable databases, and avoid hot loops on past-due deadlines or failed claim queries. Graceful shutdown stops dispatching, cancels work, waits within platform limits and leaves unfinished leases recoverable. At-least-once execution requires idempotent or fenced side effects; it is not exactly-once delivery.

### 4. Make the rest of the system idle-compatible

Inspect pool minimum connections, connection lifetime and external probes. Keep process liveness distinct from genuine database readiness; do not make readiness return success for an unavailable database to reduce cost. Adjust who polls readiness and when. Keep necessary maintenance, backups and their failure checks, grouping work where practical. Do not disable backups for a cheap bill.

Do not select LISTEN/NOTIFY merely to claim zero polling: it is non-durable and its persistent connection/provider behavior requires separate verification. The minimal same-process design does not require a new paid broker, cache or queue.

## Tradeoffs

- Coalesced local wakes give fast normal processing without a new service, but do not provide cross-process notification.
- A durable queue survives lost wakes, while a safety sweep adds bounded recovery delay and recurring database wake cost.
- Tight retries and long idle periods can coexist if known retry deadlines use timers rather than empty SQL polls.
- Autosuspend saves compute only when every other consumer permits sleep. Fixed-price VMs benefit from lower load but their server bill remains.
- A single scheduler per process avoids redundant local queries. Multiple replicas can still sweep simultaneously; use bounded jitter and measure before introducing distributed leader machinery.

## Verification checklist

- [ ] Every enqueue path commits before signalling; rollback creates no effective work.
- [ ] Empty queue has no recurring claim query before the documented sweep/deadline.
- [ ] Normal committed work wakes promptly, including work arriving at the drain/park boundary.
- [ ] Coalesced bursts drain fully with bounded concurrency and no busy wait.
- [ ] Commit-then-crash recovers through startup or the safety sweep.
- [ ] Delayed retries and expired leases recover without a new upload; retry caps remain.
- [ ] Stale workers cannot overwrite a replacement's completed work; side effects remain safe under retry.
- [ ] Two replicas, cancellation, connection failure and restart preserve jobs and tenant boundaries.
- [ ] Health, backup and external consumers are audited; no credentials or document content appear in metrics.
- [ ] Real provider observations prove suspend/resume, wake latency and compute usage; unit tests alone do not.

## Evidence limits

Only the source problem and design boundaries have been inspected. No new scheduler has been implemented or deployed, and no provider experiment has been run. Keep status draft/low until executable failure and idle-cost evidence supports promotion.
