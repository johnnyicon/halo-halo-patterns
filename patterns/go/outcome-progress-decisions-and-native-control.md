---
id: outcome-progress-decisions-and-native-control
title: Outcome Progress, Durable Decisions and Native Agent Control
type: architecture
status: draft
confidence: low
revision: 5
languages: [go, typescript, sql]
frameworks:
  - name: Gomanan with native coding-agent adapters
    version: "Forge and Codex terminal decisions and supported Codex active control verified"
    ecosystem: other
domain: state-management
tags: [agents, outcomes, decisions, scope, cancellation, idempotency]
introduced: "2026-11-10"
last_verified: "2026-11-23"
review_by: "2026-12-23"
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

| Capability | Recorded evidence reviewed through November 23, 2026 | Limit |
|---|---|---|
| Outcome progress | Actual Upstate plan view separates each requirement, evidence and remaining work. Later app verification corrected request interpretation and proved comparison, refinement, save/reopen, feasibility and explicit feedback. The fresh-account rehearsal now preserves editable original commuter records and untouched archives | The first sample test remains partial historical evidence. Some later checks use illustrative inputs; real venue prices and route estimates are separately identified. No real migration or Upstate production release occurred |
| Durable scope decisions | Both an owner-submitted Codex terminal answer and a controlled Forge answer reached their waiting Codex sessions. Forge displayed saved, delivered and acted states. Conflicting and stale replies were rejected; repeating delivery in the Forge test preserved one turn and result | Forge was agent-operated on owner instruction. The Codex test used the terminal inside the desktop app with a shared Mac login |
| Outcome observation | Live work creation stores a visible finding. On release `2b86ea0fa`, a complete material proposal created one decision on the affected task, and a retry reused it | Uncertain observations stay advisory and caller evidence is explicitly unverified |
| Stop and redirect | Supported registered Codex active turn received a redirect, produced the redirected result, then was interrupted; forbidden original and after-stop results were absent. Earlier JetStream cancellation also terminated parent and child processes and prevented stopped queued work launching | Controlled installed-Codex proof, not a claim that all native hosts or arbitrary descendants support these controls |

The verified subset can be reused within its stated limits. Draft status covers
the broader host and descendant coverage still unproved; it does not erase the
recorded checks. The checklist below applies before claiming a wider integration.

The [Upstate outcome record](https://gomanan-authority-01.tail75bb1d.ts.net/workspaces/upstate-commuter/work?open=01a1ada6-67ef-7c24-b535-1a4f50d84622)
retains the original sample-data limitation and the later sourced and illustrative
journeys separately. At Upstate revision 33fdd02, disposable database and browser
checks also proved editable copied plans, trips, experiments and costs, complete
backup/recovery and unchanged originals. This is implementation evidence, not a
claim that the owner's real records were migrated.

### Recorded integration evidence

The [stage-two decision record](https://gomanan-authority-01.tail75bb1d.ts.net/workspaces/maykapal-os/work?open=01a1b6f7-bbcb-750a-a4fa-f2a0c51f89f5)
contains the Forge and owner-submitted Codex answer evidence.
Its [controlled decision task](https://gomanan-authority-01.tail75bb1d.ts.net/workspaces/maykapal-os/work?open=01a1c835-ba48-7a0c-85ef-e7c891b39ea1)
shows the saved choice, verified delivery and evidence-backed action. These are
private workspace links; the public case study and plan above retain context.

The Forge test used one setup turn and one actual continuation. Codex read the
saved choice and wrote the matching result. A repeated delivery returned the
existing result; the native turn count and result file were unchanged. The
initial attempt failed before starting work; its failed record was retained.
When a later completed turn was initially reported as uncertain, recovery read
the actual provider record and verified the exact thread, turn, original input
and start time. It did not resend work or fabricate completion events. Where
no original acceptance timestamp existed, verified completion established the
conservative delivery timestamp; this did not invent an earlier acceptance.

The Forge test was agent-operated on the owner's explicit chat instruction.
For the Codex test, the owner personally selected “Keep the agreed scope” in
the terminal inside the Codex desktop app. Gomanan saved the choice, one waiting
turn completed in the original session, and it wrote a result matching the
decision ID, choice and digest. Forge showed the answer from Chat, delivery and
action. Delivery initially tried to steer a turn that had finished. A confirmed
rejection now lets the same request append to the idle thread. Uncertain
delivery still requires checking what happened before trying again.

The [stage-three observation and control record](https://gomanan-authority-01.tail75bb1d.ts.net/workspaces/maykapal-os/work?open=01a1b6f7-bc30-79eb-bf13-3e8832494d79)
contains actual native-control evidence `01a1cb33-9a1f-7d98-9635-ed3508c54bf9`.
Against Authority `97d6c6d0e` and worker `81e9d43f`, the explicitly enrolled Codex
session used two turns: setup completed, then the controlled proof turn was
redirected and interrupted. It wrote `REDIRECTED`; the original and after-stop
outputs were absent, including a check 117 seconds later. Repeating the original
action retained delivery attempt one and did not create a third turn. The planned
child sleep had not launched before interruption, so this proof does **not**
establish native child-process cancellation. Earlier queue/descendant evidence
must remain separate.

On November 12, the deployed material proposal created a saved decision on a
controlled draft execution. The same work request reused the task and decision.
The hosted Forge drawer showed the exact question, evidence, two choices,
recommendation and waiting work. See the [controlled affected task](https://gomanan-authority-01.tail75bb1d.ts.net/workspaces/maykapal-os/work?open=01a1d121-bb8f-7f1c-81ed-a0eb962725ce).
No agent turn ran for this check. The separately recorded owner-submitted Codex
answer and continuation complete the first supported chat surface; they do not
prove every agent host supports that interaction.

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
