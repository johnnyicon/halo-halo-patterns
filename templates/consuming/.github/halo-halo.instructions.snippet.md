## Halo-Halo Patterns Catalog

### Pattern-First Debugging

When you see an error, unexpected behavior, or an architectural decision:
1) Search `.halo-halo/upstream/patterns/` before proposing fixes.
2) Prefer applying an existing validated pattern.
3) Focus on **touched files** (changed/staged files) rather than scanning the whole repo.

### When to Capture Patterns

**Trigger `/halo-gatekeeper` if:**
- Debugging took multiple iterations
- The fix required non-obvious nuance
- The solution might apply to similar situations
- You discovered a reusable workaround

**When running gatekeeper, provide:**
- The touched files list: `git diff --name-only` or `git status --porcelain`
- A brief summary of symptoms → root cause → fix

### Workflow: Gatekeeper → Writer

1. **Gatekeeper decides** - Route to local case or upstream pattern
2. **Writer executes** - Creates the file based on routing

**Use `/halo-write-pattern` after Gatekeeper approval to:**
- Create local case file (`.halo-halo/local/cases/`)
- OR create upstream pattern draft (`.halo-halo/halo-halo-upstream/patterns/`)

### Context Gathering Rules

- **Prefer touched files over broad searches** — request git diffs, not full file reads
- **Leverage chat history** — extract incident context from recent turns
- **Sanitize always** — no internal URLs, API keys, client names, or PII
- **Search catalog first** — dedupe before creating new patterns

### Available Prompts

- `/halo-search` — Find relevant patterns for current issue
- `/halo-apply` — Apply a pattern to this repo
- `/halo-gatekeeper` — Capture a new pattern or local case (decides routing)
- `/halo-write-pattern` — Write pattern file from Gatekeeper decision
- `/halo-commit` — Safely commit local cases or upstream patterns with validation
- `/halo-health` — Audit catalog health (overdue reviews, stale patterns)
