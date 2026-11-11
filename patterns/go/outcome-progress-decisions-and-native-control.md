---
id: outcome-progress-decisions-and-native-control
title: Outcome Progress, Durable Decisions and Native Agent Control
type: architecture
status: draft
confidence: low
revision: 1
languages: [go, typescript, sql]
frameworks:
  - name: Gomanan with native coding-agent adapters
    version: "Partial implementation; end-to-end decision and control proof pending"
    ecosystem: other
domain: state-management
tags: [agents, outcomes, decisions, scope, cancellation, idempotency]
introduced: "2026-11-10"
last_verified: "2026-11-10"
review_by: "2026-12-10"
maintainers: []
sanitized: true
related: []
notes: "last_verified records evidence review, not validation of the complete integration."
---

# Keep the outcome stable across agent work

## Status and scope

This is a draft recipe prepared from Gomanan's implementation work. It does not
claim that a native agent can already be stopped or resumed reliably on every
host. The [canonical incident](https://github.com/johnnyicon/maykapal-os/blob/main/docs/case-studies/2026-11-07-autonomous-plan-runaway.md)
and [delivery plan](https://github.com/johnnyicon/maykapal-os/blob/main/docs/plans/2026-11-07-native-agent-outcome-observer-research.md)
retain the evidence and current acceptance state. The reusable execution
procedure belongs in [Galing Skills](https://github.com/johnnyicon/galing-skills/blob/main/skills/deliver-approved-outcome/SKILL.md).

| Capability | Evidence reviewed on November 10, 2026 | Limit |
|---|---|---|
| Outcome progress | Gomanan plan view demonstrated using actual Upstate records, with partial evidence and remaining gaps | Does not make the Upstate application complete |
| Durable scope decisions | Backend and task UI implemented; stale/conflicting/duplicate cases have focused tests | Actual chat and task-screen answer-to-continuation journey is still being completed |
| Outcome observation | Live work creation reads saved plan scope and stores a visible finding; deployed task drawer checked at release `02be93e53` | Observation is advisory; caller rationale is explicitly unverified |
| Stop and redirect | Real JetStream cancellation terminates parent and child processes; stopped queues refuse launch; rejected Codex interruption no longer reports success | Registered native active-turn stop/redirect integration is still being completed |

Do not promote this recipe to validated until the outstanding journeys below
have been exercised against the installed integrations and linked here.

## 1. Preserve approved scope separately from work items

Store the original outcome, approved specification revision, current milestone,
required journeys, evidence, remaining gaps, deferred discoveries and pending
decisions. A new task references an unmet requirement or observed risk; it does
not silently add a requirement. Keep partial test conditions attached to their
evidence. Avoid progress percentages derived from completed task counts.

Allow necessary long work and ordinary repairs. A suspicious activity count can
trigger a focused inquiry, not prove scope drift. Require a causal explanation
and observed failure before treating an architectural expansion as necessary.

## 2. Persist one decision, expose it through supported surfaces

Bind a decision request to its project, plan/task, specification revision and
affected execution. Save the question, evidence, choices, recommendation and
exact work waiting on the answer. Both native chat and the app render that
record rather than separate requests with independent answers.

Bind an answer to the proposal revision or digest. Reject a stale answer after
the proposal changes. Resolve simultaneous conflicting answers transactionally;
a repeated identical response returns the existing result. Carry idempotency
through delivery and execution, not merely through the answer write.

Represent **recorded**, **delivered** and **acted upon** separately. A successful
save does not prove the waiting agent received it; delivery acknowledgement does
not prove the requested action occurred. Preserve undelivered decisions across
restart and reconcile uncertain effects before retrying.

Choose the trust model explicitly. A host-provided human response, an agent
submitting an explicit owner instruction and a simulated test response are
different evidence. Signatures bind a signer and payload; a key available to
an agent does not independently prove human presence. Do not require a separate
device or login unless the owner has selected that stronger separation. Do not
relabel delegated approval as a human UI click.

## 3. Observe transitions and enforce only supported controls

Inspect admission of new work and continuation boundaries. Keep observation
inputs compact, deduplicate warnings and retain dismissed or resolved findings.
Do not create an always-running recursive reviewer hierarchy. An observer
must distinguish later authorized roadmap work from work that belongs now.

For an explicit stop or denied change, persist the execution decision, prevent
new dispatches, propagate it to supported native controls and verify resulting
state. Prevent stale continuations from re-admitting stopped work. Recheck at
queue consumption, not just publication; a job can become invalid while queued.
A late completion must not erase a stop. Report running, stopping, stopped,
unreachable and unsupported states honestly.

A Gomanan MCP response can advise an agent, but it cannot by itself enforce
control between calls. A native-host adapter must prove the supported steering
and interruption behavior, including descendants. Keep ordinary independent
work moving when only one decision-dependent branch is paused.

## Acceptance before claiming the integration works

- Demonstrate a real outcome view without turning fixture evidence into a full
  product-completion claim.
- Answer once through native chat and once through the app; observe the same
  durable decision, the other surface updating, delivery and correct action.
- Exercise stale proposals, identical retries, conflicting replies, disconnects
  and restarts. Prove repeated delivery cannot repeat the intended side effect.
- Stop active parent and descendant work; attempt a stale continuation and a
  previously queued job. Observe actual processes/jobs and saved state.
- Test missing telemetry, unreachable hosts and unsupported controls without
  falsely reporting success or starting another repair loop.
- Replay optional expansion, a necessary data-loss repair and justified long
  work. The latter two must proceed without a universal clock deadline.

Record the installed host/version, exact journey, fixture or real-data boundary,
observable result and remaining limitations for each claim. Reuse valid evidence
when inputs have not changed. No new model evaluation is implied by this recipe.
