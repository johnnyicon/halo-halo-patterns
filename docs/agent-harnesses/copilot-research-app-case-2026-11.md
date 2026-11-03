# Copilot research-app build: scope, verification and spend checkpoints

Status: preliminary case summary, November 2026. The owner supplied an executor
retrospective following a separate review of the saved code and test records.
This public summary omits the private project identity, repository references,
machine paths, conversation transcript and account-usage measurements.

## Outcome

A GitHub Copilot session delivered a new structured research-brief format,
validation and synthetic fixtures; a routed library/reader with search, notes
and saved findings; and a basic project-attachment/export flow. The complete
product was unfinished. New real-source briefing quality, additional input
formats and operational work remained unproven or incomplete.

The owner reported unexpectedly large allowance consumption during the session.
Per-turn credit/token records were unavailable. The supported finding is useful
implementation with incomplete delivery and inadequate cost visibility, not a
quantified claim about which action consumed the allowance.

## Evidence boundaries

The private review compared code to the original contract and saved runtime
manifests, inspected selected frontend/backend paths and read the saved browser
and integration reports. It did not repeat the full suite or run a new model
evaluation. The executor then provided its own retrospective, adding client and
displayed-model information, an approximate timeline and execution choices.

Those sources must remain distinguishable. Commit/test records corroborate
implementation and specific regression outcomes. The executor's description of
its thought process, unrecorded usage and approximate local iteration counts is
self-report. Actual served model, model configuration and exact cost attribution
remain unknown. A displayed frontier model name does not resolve them.

## What the retrospective adds

- The assignment covered several substantial work packages, effectively the
  remaining product. The executor says the copied launcher did not contain a
  concrete ceiling for its own coding-assistant usage.
- A separate restriction prohibited fresh model calls made by the application
  being built. That restriction did not itself count the coding assistant's
  ongoing inference. The two budgets had been conflated in discussion.
- The executor reports repeated local browser iterations followed by multiple
  integration-suite attempts. Saved reports corroborate an early failure and
  later changed-input runs ending with implementation checks passing while
  real-source quality remained blocked.
- It says it did not check usage and recognized the spend problem only when the
  owner reported it. It identifies natural checkpoints after the first work
  package, after the new browser flow passed locally, and before another full
  suite run.
- It acknowledges using full integration runs rather than the focused failing
  checks, and identifies useful non-model work it had not completed.

The complete instruction-loading history was not available. The executor's claim
that it lacked a specific budget in the launcher does not establish that no
broader owner policy existed, applied or was loaded.

## Lessons supported by this case

**Define a useful first delivery.** A whole-product instruction needs intermediate
outcomes. A structured brief contract and attractive synthetic fixture do not
prove the model explains an actual source usefully. Plan expected-content review
early and distinguish preparation from the portion requiring model permission.

**Specify two budgets.** One covers the coding assistant's own execution. The
other covers model, transcription or visual-analysis calls that the application
makes during testing. State both directly in a launcher. If usage cannot be
measured, agree an alternative bounded turn/time policy and report the gap.

**Choose tests according to the observed failure.** Use an appropriate focused
check while correcting a specific problem, then integrate. Repeating a full
suite after changed code can be justified, but its wall-clock duration does not
establish its model-credit cost. The model's surrounding turns and processed
context are a different activity from ordinary local test execution.

**Use checkpoints before spend becomes a surprise.** A completed work package
and a proposed additional integration run are opportunities to report achieved
behavior, remaining work, available usage and the next bounded action. Reporting
unfinished scope only after a large allowance increase is too late to help the
owner choose how to spend it.

**Separate test success from product completion.** Passing regression rows verify
their specific criteria. They do not assign equal weights to all remaining
features, establish new-model quality from a fixture, or demonstrate release
readiness while a required quality check remains blocked.

GitHub documents AI-credit consumption in terms of model and input/output/cached
tokens, with agentic tasks potentially making several model calls. This supports
examining conversation/context usage; it does not provide a per-action diagnosis
for this case. [GitHub billing documentation](https://docs.github.com/en/copilot/concepts/billing-and-usage/individuals/billing).

GitHub's usage view can show model-level totals, but generally does not map each
consumed credit to a particular prompt or session. Collect the available evidence
and leave the remaining attribution unknown. [Usage monitoring](https://docs.github.com/en/copilot/how-tos/manage-and-track-spending/monitor-ai-usage).

## Provisional next-use rule

Use Copilot for one bounded, reviewable change with a named completion check,
explicit executor-usage ceiling and separately authorized application-model
budget. Record the client/model configuration and the available usage at the
start and agreed checkpoints. If the requested product is larger than that
budget, agree a useful first slice before proceeding.

This is not evidence that Copilot is universally unsuitable, that its displayed
model caused the outcome, or that another agent would have finished the same
work more cheaply. A comparison would require matched starting code, task scope,
budget, independent acceptance and measured usage. Do not launch such a benchmark
merely to complete this retrospective.
