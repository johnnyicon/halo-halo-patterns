---
description: "Safely commit new Halo-Halo local cases or upstream pattern drafts with validation"
---

# Halo-Halo Commit Workflow

## Overview

Two possible commit targets:
1. **Local cases** → `.halo-halo/local/cases/` (consuming repo only)
2. **Upstream patterns** → `.halo-halo/halo-halo-upstream/patterns/` (submodule + pointer update)

**DO NOT run git commands automatically. Generate them for user to review and execute.**

---

## Step 1: Discovery

Show current state:
```bash
git status -sb
git diff --name-only .halo-halo/local/
git diff --name-only .halo-halo/halo-halo-upstream/patterns/
```

**Determine route:**
- Local cases only → Step 2A
- Upstream patterns only → Step 2B
- Both → Steps 2A + 2B

---

## Step 2A: Local Case Commit Workflow

### Pre-commit Checks:

1. **Scan for secrets:**
   ```bash
   grep -rE "api[_-]?key|token|secret" .halo-halo/local/cases/
   grep -rE "@[a-zA-Z0-9.-]+\.(com|net|org)" .halo-halo/local/cases/
   grep -rE "https?://[^/]*\.(internal|local)" .halo-halo/local/cases/
   ```

2. **Verify structure:**
   - [ ] File naming: `YYYY-MM-DD-<slug>.md`
   - [ ] Front matter includes: `id`, `date`, `resolution`
   - [ ] All 6 sections present (Context, Symptoms, Root Cause, Fix Summary, Verification, Notes)

**If checks fail → See Error Handling section below**

### Generate Commands:

```bash
# Stage local cases only
git add .halo-halo/local/cases/<YYYY-MM-DD-slug>.md

# Review staged changes
git diff --staged

# Commit with descriptive message
git commit -m "halo-halo(local): add case <YYYY-MM-DD-brief-slug>

- Context: <one-line summary>
- Resolution: <success/partial/failed>"
```

---

## Step 2B: Upstream Pattern Commit Workflow

### Pre-commit Checks:

1. **Run staleness script:**
   ```bash
   bash .halo-halo/halo-halo-upstream/scripts/staleness.sh .halo-halo/halo-halo-upstream/patterns
   ```
   **Exit code 2 = BLOCKING.** Fix overdue patterns before adding new drafts.

2. **Run verification:**
   ```bash
   bash .halo-halo/halo-halo-upstream/scripts/verify.sh $(pwd) .halo-halo/halo-halo-upstream
   ```

3. **Verify pattern metadata (read the file):**
   - [ ] All front matter fields present:
     - Required: `id`, `title`, `type`, `status`, `confidence`, `revision`
     - Required: `languages`, `frameworks`, `domain`, `tags`
     - Required: `introduced`, `last_verified`, `review_by`, `sanitized`
   - [ ] `sanitized: true` flag set
   - [ ] `status: draft` for new patterns
   - [ ] `review_by` date set (typically 90 days from `introduced`)

4. **Verify content sanitization:**
   ```bash
   # Check for internal URLs
   grep -rE "https?://[^/]*\.(internal|local|corp)" .halo-halo/halo-halo-upstream/patterns/

   # Check for API keys/tokens
   grep -rE "['\"]?[A-Za-z0-9_-]{32,}['\"]?" .halo-halo/halo-halo-upstream/patterns/ | grep -i "key\|token\|secret"

   # Check for emails (should be example.com)
   grep -rE "@(?!example\.com)[a-zA-Z0-9.-]+\.(com|net|org)" .halo-halo/halo-halo-upstream/patterns/
   ```

5. **Check index (if exists):**
   ```bash
   if [ -f .halo-halo/halo-halo-upstream/scripts/generate-index.sh ]; then
     bash .halo-halo/halo-halo-upstream/scripts/generate-index.sh
   fi
   ```

**If checks fail → See Error Handling section below**

### Generate Commands:

**Step 1: Commit to submodule:**
```bash
cd .halo-halo/halo-halo-upstream

# Stage pattern files (adjust path to actual pattern location)
git add patterns/<language>/<framework>/<domain>/<pattern-slug>.md

# If index was generated
git add patterns/INDEX.md  # (only if exists)

# Review staged changes
git diff --staged

# Commit with structured message
git commit -m "patterns(draft): add <type>/<pattern-id>

- Type: <troubleshooting|implementation|anti-pattern|architecture>
- Domain: <domain>
- Framework: <framework>/<version-range>
- Confidence: <low|medium|high>
- Review by: <YYYY-MM-DD>"

# Return to repo root
cd ../..
```

**Step 2: Update consuming repo pointer:**
```bash
# Stage submodule pointer
git add .halo-halo/halo-halo-upstream

# Review change (shows new commit hash)
git diff --staged .halo-halo/halo-halo-upstream

# Commit pointer update
git commit -m "chore: update halo-halo patterns

- Added draft: <type>/<pattern-id>"
```

**Step 3: Push (optional - only after review):**
```bash
# Push submodule changes first
cd .halo-halo/halo-halo-upstream
git push origin main

# Then push consuming repo
cd ../..
git push origin <branch-name>
```

---

## Step 3: Verification Checklist

### For Local Cases:
- [ ] No client/company names in content
- [ ] No internal URLs or API endpoints
- [ ] No API keys, tokens, or credentials
- [ ] No PII (emails, real names, addresses)
- [ ] `resolution` field set correctly (`success`/`partial`/`failed`)
- [ ] File follows naming: `YYYY-MM-DD-<slug>.md`
- [ ] All 6 sections present and filled
- [ ] `related_pattern_ids` valid (if specified)

### For Upstream Patterns:
- [ ] All front matter fields present and valid
- [ ] `sanitized: true` flag set
- [ ] `status: draft` for new patterns
- [ ] `review_by` date set (90 days from `introduced`)
- [ ] No repo-specific code (only framework patterns)
- [ ] Code examples use placeholders (example.com, User, Organization, etc.)
- [ ] Verification checklist included in pattern content
- [ ] Related patterns referenced correctly (if applicable)
- [ ] Language/framework version ranges specified
- [ ] Domain correctly categorized

### Git Hygiene:
- [ ] Commit message follows convention
- [ ] Staged only relevant files (no unrelated changes)
- [ ] Reviewed `git diff --staged` output
- [ ] Submodule pointer updated (if upstream changed)
- [ ] No merge conflicts or uncommitted changes
- [ ] Branch is up to date with main/default branch

---

## Error Handling

### Staleness Script Errors (Exit Code 2):

**Problem:** Existing patterns have overdue reviews or blocking issues.

**Fix:**
```bash
# Review flagged patterns
bash .halo-halo/halo-halo-upstream/scripts/staleness.sh .halo-halo/halo-halo-upstream/patterns

# Address blocking issues first:
# - Update overdue review_by dates (if pattern still valid)
# - Update last_verified dates (if you've verified the pattern)
# - Deprecate outdated patterns (set status: deprecated)

# Re-run to verify fixes
bash .halo-halo/halo-halo-upstream/scripts/staleness.sh .halo-halo/halo-halo-upstream/patterns
```

**Only proceed with new draft commits after exit code 0.**

---

### Sanitization Failures:

**Problem:** Found internal URLs, API keys, or PII in content.

**Common patterns to fix:**

```bash
# Internal URLs
s/https?:\/\/[^/]*\.(internal|local|corp)[^)>\s]*/https:\/\/api.example.com/g

# Company/client names
s/ClientCorp/Organization/g
s/client-api/api-service/g

# API keys (example pattern)
s/sk_live_[A-Za-z0-9]{32}/YOUR_API_KEY/g
s/Bearer [A-Za-z0-9_-]{20,}/Bearer <YOUR_TOKEN>/g

# Email addresses
s/john@clientcorp\.com/user@example.com/g
s/([a-z]+)@(?!example\.com)[a-z.-]+\.com/\1@example.com/g

# Repo-specific class names (replace with generic)
s/ClientDocument/Document/g
s/CompanyUser/User/g
```

**After fixing:**
1. Re-run sanitization checks
2. Verify `sanitized: true` flag is set
3. Commit only after clean scan

---

### Missing Front Matter:

**Problem:** Pattern file missing required metadata fields.

**Fix:**
1. **Preferred:** Re-run `/halo-write-pattern` with corrected metadata
2. **Manual edit (only if needed):**
   - Open pattern file
   - Add missing fields from template
   - Verify all required fields present
   - Set `sanitized: true`
   - Set `review_by` to 90 days from `introduced`

**Required fields:**
```yaml
id: "pattern-<language>-<framework>-<slug>"
title: "Descriptive Pattern Title"
type: troubleshooting|implementation|anti-pattern|architecture
status: draft
confidence: low|medium|high
revision: 1
languages:
  - language: <lang>
    versions: "<version-range>"
frameworks:
  - name: <framework>
    versions: "<version-range>"
domain: <domain>
tags: [<tag1>, <tag2>]
introduced: YYYY-MM-DD
last_verified: YYYY-MM-DD
review_by: YYYY-MM-DD
sanitized: true
related: []
```

---

### Verification Script Failures:

**Problem:** Installation verification fails.

**Common issues:**
1. **Wrong working directory:** Run from consuming repo root
2. **Missing submodule:** Run `git submodule update --init --recursive`
3. **Missing prompts:** Re-run install script

**Fix:**
```bash
# Re-initialize submodule
git submodule update --init --recursive

# Re-run install
bash .halo-halo/halo-halo-upstream/scripts/install.sh .

# Verify installation
bash .halo-halo/halo-halo-upstream/scripts/verify.sh . .halo-halo/halo-halo-upstream
```

---

## Example Output

**Scenario: Local case + upstream pattern both changed**

```markdown
## Discovery Results

**Local cases changed:**
- .halo-halo/local/cases/2026-01-08-rails-stimulus-portal.md

**Upstream patterns changed:**
- .halo-halo/halo-halo-upstream/patterns/ruby/rails/view_components/stimulus-portal-disconnect.md

---

## Pre-commit Check Results

### Local Case Checks:
✅ No secrets found
✅ File naming correct: 2026-01-08-rails-stimulus-portal.md
✅ Front matter valid (id, date, resolution: success)
✅ All 6 sections present

### Upstream Pattern Checks:
✅ Staleness script passed (exit code 0)
✅ Verification script passed
✅ All front matter fields present
✅ sanitized: true flag set
✅ No internal URLs found
✅ No API keys found
✅ No PII found

---

## Commands to Run

### 1. Commit Local Case:

```bash
git add .halo-halo/local/cases/2026-01-08-rails-stimulus-portal.md
git diff --staged
git commit -m "halo-halo(local): add case 2026-01-08-rails-stimulus-portal

- Context: Stimulus controller disconnects after ViewComponent portal move
- Resolution: success"
```

### 2. Commit Upstream Pattern:

```bash
cd .halo-halo/halo-halo-upstream
git add patterns/ruby/rails/view_components/stimulus-portal-disconnect.md
git diff --staged
git commit -m "patterns(draft): add troubleshooting/stimulus-portal-disconnect

- Type: troubleshooting
- Domain: view_components
- Framework: rails/>=7.0
- Confidence: high
- Review by: 2026-04-08"
cd ../..
```

### 3. Update Submodule Pointer:

```bash
git add .halo-halo/halo-halo-upstream
git diff --staged .halo-halo/halo-halo-upstream
git commit -m "chore: update halo-halo patterns

- Added draft: troubleshooting/stimulus-portal-disconnect"
```

### 4. Push (after review):

```bash
cd .halo-halo/halo-halo-upstream
git push origin main
cd ../..
git push origin feature-branch
```

---

## Verification Checklist

**Before pushing, verify:**

Local case:
- [x] No secrets or PII
- [x] File naming correct
- [x] All sections present
- [x] Resolution field set

Upstream pattern:
- [x] All front matter valid
- [x] sanitized: true
- [x] status: draft
- [x] Code examples use placeholders
- [x] Verification checklist in pattern

Git:
- [x] Reviewed all staged diffs
- [x] Commit messages follow convention
- [x] No unrelated changes included
- [x] Submodule pointer updated

**Ready to push!** ✅
```

---

## Notes

- **Always review `git diff --staged` before committing**
- **Never commit API keys, tokens, internal URLs, or PII**
- **Upstream patterns must have `sanitized: true` flag**
- **Run staleness checks before adding new patterns**
- **Submodule commits happen before pointer updates**
- **Push submodule changes before consuming repo**

---

## Related Prompts

- `/halo-write-pattern` - Create pattern files (must run before commit)
- `/halo-gatekeeper` - Decide local vs upstream routing (must run before write-pattern)
- `/halo-health` - Check catalog health (should pass before adding drafts)
