---
description: Halo Install Wizard — smart merge of Halo instructions into existing Copilot config
---

You are installing/updating the Halo-Halo Patterns Catalog into this repository.

## Step 0: Locate Existing Instructions

Check for existing Copilot instruction files:
- `.github/copilot-instructions.md` (standard location)
- `.github/instructions/*.md` (alternative)
- `docs/ai/*.md` (alternative)
- Any other custom instruction files

Identify which file(s) are authoritative for this repo.

## Step 1: Run Installer

Execute: `bash .patterns/catalog/scripts/install.sh .`

This will:
- Copy Halo prompts/agents to `.github/`
- Create `.patterns/local/{cases,scratch}`
- Add gitignore block
- **Attempt safe merge** into `copilot-instructions.md`

## Step 2: Verify Instructions Merge

Check `.github/copilot-instructions.md` for the Halo block:
```markdown
<!-- halo-halo:start version=0.1 -->
... Halo instructions ...
<!-- halo-halo:end -->
```

**If merge looks good:**
- Confirm the Halo section doesn't conflict with existing rules
- Check formatting/readability
- Done!

**If there are conflicts or the file has unusual structure:**
- Read `.github/halo-halo.instructions.snippet.md`
- Manually place the Halo block in the most appropriate section
- Preserve all existing instructions
- Add compatibility notes if rules conflict

## Step 3: Verify Installation

Confirm these exist:
- ✅ `.patterns/catalog/` (git submodule)
- ✅ `.patterns/local/cases/` and `.patterns/local/scratch/`
- ✅ `.github/prompts/halo/halo-{search,apply,gatekeeper}.prompt.md`
- ✅ `.github/agents/halo/halo-gatekeeper.agent.md`
- ✅ Halo block in `copilot-instructions.md`

## Step 4: Test Prompts

Try these in Copilot Chat:
- `/halo-search` — should search `.patterns/catalog/patterns/`
- `/halo-gatekeeper` — should prompt for context packet
- `/halo-apply` — should ask for pattern ID and touched files

## Output

Report:
```markdown
### Installation Status: [✅ Complete | ⚠ Manual Merge Needed | ❌ Blocked]

**Files Modified:**
- ...

**Conflicts Found:**
- [None | List any instruction conflicts]

**Next Actions:**
- [What user should do next, if anything]
```

## Important Constraints

- **Never overwrite existing repo instructions** — only add/update Halo block
- **Preserve existing structure** — don't reorder or reformat
- **Resolve conflicts gracefully** — document incompatibilities, don't force
- **Be idempotent** — running this multiple times should be safe
