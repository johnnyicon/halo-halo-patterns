# Skill: Halo-Halo Patterns

Search, apply, and contribute to the Halo-Halo pattern library — a curated catalog of vetted programming patterns and troubleshooting guides across languages and frameworks.

**Catalog location (upstream repo):** `/Users/kanekoa/Workspace/halo-halo-patterns/patterns/`
**Catalog location (consuming repo):** `.halo-halo/upstream/patterns/`

---

## Trigger phrases

**Search:**
- "Search halo-halo for..."
- "Check halo-halo patterns"
- "Any patterns related to this?"
- "Is there a halo-halo pattern for..."
- "Search the pattern library"
- "halo search ..."

**Apply:**
- "Apply the halo pattern"
- "Apply that pattern to this repo"
- "halo apply"
- "Turn that pattern into a change plan"

**Gatekeeper / Capture:**
- "Add a halo-halo pattern for this"
- "This should be a halo-halo pattern"
- "Log this as a pattern"
- "Capture this bug as a pattern"
- "We should document this in halo-halo"
- "Run the gatekeeper"
- "halo gatekeeper"
- "halo capture"

**Write Pattern:**
- "Write the pattern file"
- "halo write"
- "Write the halo pattern"
- "Create the pattern file from the gatekeeper decision"

**Commit:**
- "Commit the halo pattern"
- "halo commit"
- "Safely commit this pattern"
- "Run the halo commit workflow"

**Health Check:**
- "Check halo-halo health"
- "Any stale patterns?"
- "halo health"
- "Run the halo health check"

---

## Mode: Search

When the user asks to search the pattern library, follow these steps:

### Step 1: Extract search context

From the current conversation, identify:
- **Keywords** — error messages, framework names, symptoms
- **Domain** — one of the 16 domains (see Domain Values below)
- **Language/framework** — what tech stack is involved
- **Tags** — specific concepts (e.g., "stale-cache", "race-condition", "HMR")

### Step 2: Search the catalog

Determine catalog path:
- In the upstream repo: `/Users/kanekoa/Workspace/halo-halo-patterns/patterns/`
- In a consuming repo: `.halo-halo/upstream/patterns/`

Search by:
1. **Grep for keywords** from symptoms, error messages, and root cause in all `.md` files
2. **Match by domain** — check `domain:` in front matter
3. **Match by tags** — check `tags:` in front matter
4. **Match by framework** — check `frameworks:` in front matter

Search broadly — check title, tags, symptoms, root cause sections.

### Step 3: Report findings

For each match, report:
- Pattern ID and title
- Confidence: `exact` (same root cause), `close` (similar domain/symptoms), `tangential` (related concept)
- Key insight from the pattern that applies
- File path for the user to read

If no matches found, say so and suggest running the gatekeeper if the current session uncovered something novel.

---

## Mode: Apply

When the user wants to apply a pattern to their current repo:

### Step 1: Gather context

**Required inputs:**
- Pattern ID or pattern excerpt (from search or direct reference)
- **Touched files list** — ask the user to run:
  - `git diff --name-only` (uncommitted changes)
  - OR `git show --name-only --pretty="" HEAD` (committed)
  - OR VS Code "Files changed" list

Do not proceed without touched files unless explicitly unavailable.

### Step 2: Read the pattern

Retrieve the pattern from the catalog. Extract:
- Root cause
- Fix approach
- Verification checklist
- Tradeoffs

### Step 3: Build a repo-specific plan

**Limit scope to touched files** (plus 1–2 adjacent config files if needed).

Output:
```markdown
### Apply Plan: [pattern-id]

**Files to modify:**
- `path/to/file.ts` — [what changes]

**Changes:**
1. [Step-by-step instructions]

**Verification:**
- [ ] [From pattern checklist, adapted to this repo]

**Tradeoffs:**
- [Any performance/complexity trade-offs from the pattern]

**Rollback:**
- [How to undo if this doesn't work]
```

### Step 4: Request minimal context

If you need code excerpts:
- Request **only touched files**
- Ask for specific line ranges or diffs
- Do not scan the entire repo

---

## Mode: Gatekeeper (Capture)

When the user wants to document a new learning, run the full gatekeeper process:

### Step 1: Build Context Packet

Extract from the current conversation:
- **Symptoms** — what broke or behaved unexpectedly
- **Root Cause** — what the actual issue was (be specific)
- **Fix** — what changed to resolve it
- **Verification** — how it was confirmed working
- **Environment** — language, framework, runtime, versions

**Gather touched files:**
Run `git diff --name-only` or ask the user. Do not proceed without a file list unless explicitly unavailable.

### Step 2: Dedupe Against Catalog

Search the catalog for similar patterns by:
- Keywords from symptoms and fix
- Domain and tags
- Root cause type

Classify: **exact match**, **close match**, or **novel**.

### Step 3: Route Decision

Apply routing rules from `/Users/kanekoa/Workspace/halo-halo-patterns/rules/gatekeeper.json`:

**CATALOG (upstream)** — Score 8+, reusable across projects:
- Write to `patterns/<language>/<framework>/<pattern-slug>.md`
- Full front matter (see schema below)
- All required sections for the pattern type

**LOCAL** — Score 5-7, project-specific:
- Write to the project's `.halo-halo/local/cases/YYYY-MM-DD-slug.md`
- Minimal front matter

**CONSOLIDATE** — Close match found:
- Propose update to existing pattern (show diff with new nuance)

### Step 4: Sanitize

**Remove before writing:**
- Internal URLs, domain names, hostnames
- API keys, tokens, credentials
- Client names, team names, usernames
- PII (emails, real names)

Replace with: `<DOMAIN>`, `<API_KEY>`, `<CLIENT>`, etc.

### Step 5: Output format

```markdown
### Context Packet
- Symptoms: ...
- Root Cause: ...
- Fix: ...
- Environment: ...
- Touched Files: [...]

### Routing Decision
[CATALOG | LOCAL | CONSOLIDATE]: <rationale>

### Proposed File
Path: `patterns/.../pattern-id.md` OR `.halo-halo/local/cases/...`

<full markdown content here>
```

Present for review and ask for confirmation before writing.

---

## Mode: Write Pattern

When the user wants to write the pattern file after a Gatekeeper decision:

### Step 1: Confirm routing

Ask the user to confirm:
- Local case → `.halo-halo/local/cases/YYYY-MM-DD-<slug>.md`
- Upstream catalog → `patterns/<language>/<framework>/<pattern-slug>.md`

### Step 2: Gather information

**For local case:**
- Date, slug, context, symptoms, root cause, fix, verification, notes
- `related_pattern_ids` if any

**For upstream pattern:**
- All front matter fields (id, title, type, confidence, language, framework, domain, tags)
- Pattern type determines required sections
- Code examples (sanitized)

### Step 3: Apply sanitization

- Replace internal URLs → `https://api.example.com`
- Replace client/company names → `Organization`, `Client`
- Remove API keys/tokens → `YOUR_API_KEY`, `<redacted>`
- Strip PII → `user@example.com`, `User A`
- Use generic class names unless framework-standard

### Step 4: Write and confirm

Show the user:
1. Full file path
2. Preview of content (first 50 lines)
3. Sanitization applied

Ask for confirmation before writing.

**Local case template:**
```yaml
---
id: case-YYYYMMDD-001
date: YYYY-MM-DD
related_pattern_ids: []
resolution: success  # or partial, failed
---

## Context
## Symptoms
## Root Cause
## Fix Summary
## Verification
## Notes
```

**Upstream pattern front matter:**
```yaml
---
id: "<kebab-case-id>"
title: "<descriptive title>"
type: troubleshooting | implementation | architecture | anti-pattern
status: draft
confidence: low | medium | high
revision: 1

languages:
  - language: <language>
    versions: "<version-range>"

frameworks:
  - name: "<framework>"
    versions: "<version-range>"

domain: <one of 16 domains>
tags: [<keywords>]

introduced: <YYYY-MM-DD>
last_verified: <YYYY-MM-DD>
review_by: <YYYY-MM-DD, +90 days>

maintainers: ["@kanekoa"]
sanitized: true
related: []
---
```

**Required sections by type:**
- `troubleshooting`: Context, Symptoms, Root Cause, Fix, Verification Checklist
- `implementation`: Context, Usage, Tradeoffs, Verification Checklist
- `architecture`: Context, Decision, Tradeoffs, When to Use, When NOT to Use
- `anti-pattern`: Context, Why This Fails, What to Do Instead, Detection

---

## Mode: Commit

When the user wants to commit halo-halo changes. **Generate commands for review — do not run automatically.**

### Step 1: Discovery

Show current state:
```bash
git status -sb
```

Determine route: local cases only, upstream patterns only, or both.

### Step 2A: Local case commit

**Pre-commit checks:**
- Scan for secrets: API keys, internal URLs, PII
- Verify file naming: `YYYY-MM-DD-<slug>.md`
- Verify front matter: `id`, `date`, `resolution`
- Verify all 6 sections present

**Commands:**
```bash
git add .halo-halo/local/cases/<YYYY-MM-DD-slug>.md
git diff --staged
git commit -m "halo-halo(local): add case <YYYY-MM-DD-brief-slug>

- Context: <one-line summary>
- Resolution: <success/partial/failed>"
```

### Step 2B: Upstream pattern commit

**Pre-commit checks:**
1. Run staleness check (exit code 2 = BLOCKING, fix before adding drafts)
2. Verify all front matter fields present
3. Verify `sanitized: true` flag set
4. Verify no internal URLs, API keys, or PII

**Commands:**
```bash
# In upstream repo or submodule
git add patterns/<language>/<framework>/<pattern-slug>.md
git diff --staged
git commit -m "patterns(draft): add <type>/<pattern-id>

- Type: <troubleshooting|implementation|anti-pattern|architecture>
- Domain: <domain>
- Framework: <framework>/<version-range>
- Confidence: <low|medium|high>
- Review by: <YYYY-MM-DD>"
```

If working via submodule in a consuming repo, also update the submodule pointer:
```bash
cd ../..
git add .halo-halo/halo-halo-upstream
git commit -m "chore: update halo-halo patterns

- Added draft: <type>/<pattern-id>"
```

### Step 3: Verification checklist

- [ ] No secrets, internal URLs, or PII
- [ ] `sanitized: true` flag set on upstream patterns
- [ ] `status: draft` on new patterns
- [ ] `review_by` set to 90 days from `introduced`
- [ ] Commit messages follow convention
- [ ] Staged only relevant files

---

## Mode: Health Check

Run the staleness check:

```bash
bash /Users/kanekoa/Workspace/halo-halo-patterns/scripts/staleness.sh /Users/kanekoa/Workspace/halo-halo-patterns/patterns
```

For consuming repos:
```bash
bash .halo-halo/upstream/scripts/staleness.sh .halo-halo/upstream/patterns
```

Report:
- Overdue `review_by` dates (BLOCKING)
- Patterns not verified in 180+ days (warning)
- Total pattern count and coverage stats

---

## Domain Values

`state-management`, `caching`, `indexing`, `authentication`, `authorization`, `data-fetching`, `forms`, `routing`, `error-handling`, `testing`, `performance`, `deployment`, `database`, `api-design`, `concurrency`, `observability`

---

## Pattern Directory Convention

```
patterns/<language>/                            # go, ruby, typescript, etc.
patterns/<language>/<framework>/                # rails, nextjs, react, etc.
patterns/<language>/<framework>/<domain>/       # optional subdomain grouping
patterns/<language>/<pattern-slug>.md           # language-level (no framework)
```

---

## Key Files

| File | Purpose |
|------|---------|
| `patterns/` | The catalog — all patterns live here |
| `schema/pattern.schema.json` | JSON Schema for front matter validation |
| `rules/gatekeeper.json` | Routing thresholds and quality caps |
| `rules/lifecycle.json` | Status lifecycle and section requirements |
| `rules/sanitization.json` | Secret detection patterns |
| `scripts/staleness.sh` | Health check script |
| `docs/TEMPLATE.md` | Pattern file template |
| `docs/CONTRIBUTING.md` | Contribution guidelines |
| `skills/SKILL.md` | **This file — source of truth for the global skill** |

All paths relative to `/Users/kanekoa/Workspace/halo-halo-patterns/`.
