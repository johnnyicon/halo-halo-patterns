---
id: "claude-code-subagent-model-routing"
title: "Claude Code: Give Subagents and Workflow Agents Their Own Default Model"
type: recipe
status: draft
confidence: medium
revision: 1

languages: []
frameworks: []
dependencies:
  - name: claude-code
    versions: ">=2.1.315"
domain: development-workflow
tags:
  - claude-code
  - subagents
  - workflows
  - model-routing
  - token-cost

introduced: 2026-11-27
last_verified: 2026-11-27
review_by: 2027-02-27

maintainers: ["@kanekoa"]
deprecated_date: null
superseded_by: null
---

# Claude Code: give subagents and workflow agents their own default model

## The problem

Subagents and workflow agents run on the main session's model unless told otherwise. A
session on the most capable model then spends that model on every builder, reviewer,
and searcher it spawns.

Observed on the home-designer project, 26 to 27 November 2026:

| Workflow | Agents | Model | Time | Subagent tokens |
|---|---|---|---|---|
| Build a design rules engine | 6 | session model (Fable 5.2) | 78 min | 1.58 million |
| Build design options | 5 | session model (Fable 5.2) | 54 min | 1.37 million |
| Fix two rule defects | 3 | Sonnet 5.5, named per agent | 6 min | 423 thousand |

The third task was much smaller than the first two, so this is not a like-for-like
comparison of the models. It does show the routing took effect: every agent reported
running as `claude-sonnet-5-5`.

## What the setting is

It is not a switch in the app. It is two environment variables, which Claude Code reads
from the `env` block of a settings file (a JSON configuration file):

```json
{
  "env": {
    "CLAUDE_CODE_SUBAGENT_MODEL": "sonnet",
    "CLAUDE_CODE_SUBAGENT_EFFORT": "medium"
  }
}
```

- `CLAUDE_CODE_SUBAGENT_MODEL`: default model for subagents, team teammates, and
  workflow agents that are not given a model another way. Takes an alias (`sonnet`,
  `opus`, `haiku`, `fable`) or a full model name. `inherit` is the same as unset.
- `CLAUDE_CODE_SUBAGENT_EFFORT`: default effort for subagents and workflow agents
  (`low`, `medium`, `high`, `xhigh`, `max`). Needs Claude Code 2.1.315 or later.
- `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` forces one model onto every agent and ignores
  per-agent choices. Do not use it when a workflow routes different stages to different
  models.

Where the file lives decides the scope:

| File | Applies to |
|---|---|
| `<repo>/.claude/settings.json` | Everyone working in that repository (commit it) |
| `<repo>/.claude/settings.local.json` | Only you, in that repository (not committed) |
| `~/.claude/settings.json` | All your projects on that machine |

A session reads its environment when it starts, so the change applies to sessions
started after the edit.

## Order of precedence

Model, highest first:

1. The model named in the call (`agent(prompt, { model: 'haiku' })` in a workflow
   script, or the `model` parameter of a subagent call).
2. The `model` field of a custom agent definition (`.claude/agents/<name>.md`).
3. `CLAUDE_CODE_SUBAGENT_MODEL`.
4. The main session's model.

So the environment variable is the floor, and a script can still send one stage to
Haiku and another to Opus.

The built-in Explore and Plan subagents are not changed by
`CLAUDE_CODE_SUBAGENT_MODEL` alone.

## Recommended routing

| Work | Model | Effort |
|---|---|---|
| Planning, contracts, test gates, browser checks, commits | Main session | Session default |
| Building from a written contract, reviewing, fixing | Sonnet | medium |
| Hard debugging, real design trade-offs, settling a builder/reviewer disagreement | Opus | medium to high |
| Searching, extracting fields, classifying, format-and-test loops | Haiku | low |

Default to Sonnet, not Opus: the default covers the common case, and the common case in
a workflow is scoped building and reviewing from a written contract. Name Opus on the
stages that need it.

## How to apply it in a workflow

- Record the model on the work item when planning (in Gomanan:
  `gomanan tracker brief update <id> --recommended-model <model>`).
- In the script, name the model on every `agent()` call, taken from the work item.
- Have each agent report the model it ran as, and check that on the first run.
- Keep a review stage. On the Sonnet run above, the Sonnet reviewer caught a real defect
  in the Sonnet builder's work.

## Sources

Claude Code documentation, read 27 November 2026: "Sub-agents" (choose a model, choose
an effort level, run every subagent on one model), "Environment variables", "Workflows".
The accepted values of `model` and `effort` on a workflow script's `agent()` call are
described in the workflow authoring reference, not on those pages.
