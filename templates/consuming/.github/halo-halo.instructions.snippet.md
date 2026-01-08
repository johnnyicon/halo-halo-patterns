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
- The touched files list: `git diff --name-only` or `git status --porceloin`
- A brief summary of symptoms → root cause → fix

### Context Gathering Rules

- **Prefer touched files over broad searches** — request git diffs, not full file reads
- **Leverage chat history** — extract incident context from recent turns
- **Sanitize always** — no internal URLs, API keys, client names, or PII
- **Search catalog first** — dedupe before creating new patterns

### Available Prompts

- `/halo-search` — Find relevant patterns for current issue
- `/halo-apply` — Apply a pattern to this repo
- `/halo-gatekeeper` — Capture a new pattern or local case
