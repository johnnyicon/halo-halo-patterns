---
description: Apply Pattern — turn a chosen pattern into a repo-specific change plan + verification.
---

You are applying a Halo pattern to this repository.

## Step 1: Gather Context

**Required inputs:**
- Pattern ID or pattern excerpt (from `/halo-search` or direct reference)
- **Touched files list** — ask user to provide:
  - `git diff --name-only` (uncommitted changes)
  - OR `git show --name-only --pretty="" HEAD` (committed)
  - OR VS Code "Files changed" list

**Do not proceed without touched files** unless explicitly unavailable.

## Step 2: Read Pattern

Retrieve the pattern from `.halo-halo/upstream/patterns/`.
Extract:
- Root cause
- Fix approach
- Verification checklist
- Tradeoffs

## Step 3: Build Repo-Specific Plan

**Limit scope to touched files** (plus 1–2 adjacent config files if needed).

Output:
```markdown
### Apply Plan: [pattern-id]

**Files to modify:**
- `path/to/file.ts` — [what changes]
- `path/to/config.json` — [what changes]

**Changes:**
1. [Step-by-step instructions]
2. ...

**Verification:**
- [ ] [From pattern checklist, adapted to this repo]
- [ ] ...

**Tradeoffs:**
- [Any performance/complexity trade-offs from the pattern]

**Rollback:**
- [How to undo if this doesn't work]
```

## Step 4: Request Minimal Context

If you need code excerpts:
- Request **only touched files**
- Ask for specific line ranges or diffs
- Do not scan the entire repo
