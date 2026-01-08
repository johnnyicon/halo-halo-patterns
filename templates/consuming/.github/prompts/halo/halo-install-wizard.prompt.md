---
description: Halo Install Wizard — automated installation with smart merge verification
---

You are installing/updating the Halo-Halo Patterns Catalog into this repository.

## Step 0: Pre-Flight Check

1. Verify `.halo-halo/upstream/` submodule exists (if not, user must add it first)
2. Locate existing Copilot instruction files:
   - `.github/copilot-instructions.md` (standard)
   - `.github/instructions/*.md` (alternative)
   - `docs/ai/*.md` (alternative)
3. Read existing instructions to understand structure/style

## Step 1: Run Installer Script

**Run the install script** (you may need to approve execution):
```bash
bash .halo-halo/upstream/scripts/install.sh .
```

If you cannot execute directly, **instruct the user to run it** and wait for their confirmation.

**What this script does:**
- Copies Halo prompts/agents to `.github/prompts/halo/` and `.github/agents/halo/`
- Creates `.halo-halo/local/{cases,scratch}`
- Adds `.halo-halo/local/**` to `.gitignore` (idempotent)
- Merges Halo instructions into `copilot-instructions.md` using marker blocks

**After execution, capture:**
- Script output/errors
- Files created/modified
- Any warnings

## Step 2: Verify Instructions Merge

Read `.github/copilot-instructions.md` and check:

**Look for the Halo marker block:**
```markdown
<!-- halo-halo:start version=0.1 -->
... Halo instructions ...
<!-- halo-halo:end -->
```

**Verification checklist:**
- [ ] Marker block present and complete
- [ ] No conflicts with existing repo rules
- [ ] Formatting is clean and readable
- [ ] Halo section is in appropriate location (not breaking flow)

**If issues found:**
- Read `.github/halo-halo.instructions.snippet.md`
- Manually adjust placement/formatting
- Resolve any rule conflicts (document compatibility notes)
- Never delete existing instructions

## Step 3: Verify File Structure

Confirm these paths exist:
- ✅ `.halo-halo/upstream/` (git submodule, should already exist)
- ✅ `.halo-halo/local/cases/`
- ✅ `.halo-halo/local/scratch/`
- ✅ `.github/prompts/halo/halo-search.prompt.md`
- ✅ `.github/prompts/halo/halo-apply.prompt.md`
- ✅ `.github/prompts/halo/halo-gatekeeper.prompt.md`
- ✅ `.github/agents/halo/halo-gatekeeper.agent.md`
- ✅ `.github/halo-halo.instructions.snippet.md` (for future reference)

Check `.gitignore` contains:
```
# --- halo-halo-patterns:local-start ---
.halo-halo/local/**
!.halo-halo/local/README.md
# --- halo-halo-patterns:local-end ---
```

## Step 4: Test Prompts (Optional)

Suggest user try:
- `/halo-search` — searches `.halo-halo/upstream/patterns/`
- `/halo-gatekeeper` — prompts for context packet
- `/halo-apply` — asks for pattern ID and touched files

## Final Output

Report installation status:

```markdown
### Installation Status: [✅ Complete | ⚠ Manual Merge Needed | ❌ Blocked]

**Script Output:**
<paste relevant output>

**Files Created/Modified:**
- .github/copilot-instructions.md (Halo block added/updated)
- .github/prompts/halo/* (3 prompts)
- .github/agents/halo/* (1 agent)
- .halo-halo/local/cases/ (created)
- .halo-halo/local/scratch/ (created)
- .gitignore (Halo block appended)

**Issues Found:**
- [None | List any conflicts or warnings]

**Manual Actions Required:**
- [None | List what user should do]

**Next Steps:**
1. Try `/halo-search <symptom keywords>` to test
2. Start capturing patterns with `/halo-gatekeeper`
```

## Important Constraints

- **Run the script first** — don't ask permission, just execute it (it's idempotent)
- **Never overwrite repo instructions** — only add/update Halo marker block
- **Be specific about errors** — if something fails, show exact error and suggest fix
- **Verify before declaring success** — check files actually exist

- **Never overwrite existing repo instructions** — only add/update Halo block
- **Preserve existing structure** — don't reorder or reformat
- **Resolve conflicts gracefully** — document incompatibilities, don't force
- **Be idempotent** — running this multiple times should be safe
