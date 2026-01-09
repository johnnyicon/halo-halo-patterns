---
name: halo-checkin
description: Formalized versioned check-in for Halo-Halo changes — validates version bump, updates changelog, and commits.
---

# Halo-Halo Versioned Check-In Orchestrator

Purpose: Execute a strict, repeatable process when "checking in changes" to Halo-Halo.

**WHEN TO USE:** When ready to release accumulated changes as a new version.

**LOCATION:** Run this from `.halo-halo/halo-halo-upstream/` directory (the submodule).

---

## Phase 1: Gather Context

**Ask user if not provided:**
1. Change summary: What changed (templates, prompts, agents, scripts)?
2. Change type: patch | minor | major?
3. Breaking changes: yes/no?

**Then detect current state:**

```bash
git log --oneline -5  # Show recent commits
grep -A 5 "^## \[" CHANGELOG.md | head -20  # Show latest versions
cat .halo-version  # Show current version
```

### Checklist: Phase 1
- [ ] Change summary collected
- [ ] Change type determined (patch/minor/major)
- [ ] Breaking changes identified (yes/no)
- [ ] Current version detected from CHANGELOG
- [ ] Recent commits reviewed

**STOP: Show findings to user before proceeding to Phase 2**

---

## Phase 2: Version Calculation

**Determine next version:**
- If `major` → bump X+1.0.0
- If `minor` → bump X.Y+1.0
- If `patch` → bump X.Y.Z+1

**Verify version doesn't already exist:**
```bash
grep "^## \[$NEW_VERSION\]" CHANGELOG.md  # Should return empty
```

### Checklist: Phase 2
- [ ] Next version calculated (show: current → new)
- [ ] Verified version doesn't exist in CHANGELOG
- [ ] Version bump logic matches change type

**STOP: Show version bump plan to user before proceeding to Phase 3**

---

## Phase 3: CHANGELOG Update

**Move [Unreleased] → [X.Y.Z]:**
1. Read current `[Unreleased]` section from CHANGELOG.md
2. Create new `## [X.Y.Z] - YYYY-MM-DD` section
3. Move all entries from `[Unreleased]` to new version section
4. Ensure categorization: Added, Changed, Fixed, Removed
5. Verify LLM-actionable instructions are included
6. Leave new empty `[Unreleased]` section

### Checklist: Phase 3
- [ ] Read current `[Unreleased]` content
- [ ] Created `[X.Y.Z]` section with today's date
- [ ] Moved all entries from Unreleased → versioned section
- [ ] Verified categories (Added/Changed/Fixed/Removed)
- [ ] Verified LLM-actionable instructions present
- [ ] New empty `[Unreleased]` section remains

**STOP: Show CHANGELOG diff before proceeding to Phase 4**

---

## Phase 4: Update .halo-version

**Update version file:**

```yaml
version: X.Y.Z
updated: YYYY-MM-DD
```

### Checklist: Phase 4
- [ ] .halo-version updated with new version
- [ ] Date updated to today

**STOP: Show .halo-version content before proceeding to Phase 5**

---

## Phase 5: Commit Changes

**Create commit:**

```bash
git add CHANGELOG.md .halo-version scripts/ templates/
git commit -m "chore: release v$NEW_VERSION

$(cat <<EOF
Changes in this release:
- [Summary from CHANGELOG]

See CHANGELOG.md for full details.
EOF
)"
```

### Checklist: Phase 5
- [ ] All changed files staged
- [ ] Commit message includes version
- [ ] Commit message includes summary
- [ ] Commit created successfully

**STOP: Show commit details before proceeding to Phase 6**

---

## Phase 6: Tag Release

**Create git tag:**

```bash
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION

$(grep -A 20 "^## \[$NEW_VERSION\]" CHANGELOG.md | sed '/^## \[/,$d')"

git tag -l "v$NEW_VERSION" -n10  # Verify tag
```

### Checklist: Phase 6
- [ ] Tag created with version number
- [ ] Tag includes changelog excerpt
- [ ] Tag verified

**STOP: Show tag details before proceeding to Phase 7**

---

## Phase 7: Push to Remote

**Push changes:**

```bash
git push origin main
git push origin "v$NEW_VERSION"
```

### Checklist: Phase 7
- [ ] Commits pushed to origin/main
- [ ] Tag pushed to remote
- [ ] Verify on GitHub

---

## Final Summary

**Version Released:** `vX.Y.Z`

**Files Updated:**
- CHANGELOG.md
- .halo-version
- [Any other modified files]

**Next Steps for Consuming Repos:**
1. Update submodule: `cd .halo-halo/halo-halo-upstream && git pull`
2. Re-run install script: `bash .halo-halo/halo-halo-upstream/scripts/install.sh .`
3. Verify: `bash .halo-halo/halo-halo-upstream/scripts/verify.sh .`

---

**Remember:** Never bypass this checkin process. All Halo-Halo changes must go through versioned releases.
