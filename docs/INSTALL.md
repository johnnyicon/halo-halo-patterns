# Install into a consuming repository

## Method 1: Prompt-Orchestrated Install (Recommended)

```bash
# 1. Add catalog as submodule
git submodule add https://github.com/johnnyicon/halo-halo-patterns.git .patterns/catalog
git submodule update --init --recursive

# 2. Run install wizard in GitHub Copilot Chat
/halo-install-wizard
```

The wizard will:
- Run the install script automatically
- Verify the installation
- Handle edge cases with existing instructions
- Report any issues

## Method 2: Script-Only Install

```bash
# 1. Add catalog as submodule
git submodule add https://github.com/johnnyicon/halo-halo-patterns.git .patterns/catalog
git submodule update --init --recursive

# 2. Run install script directly
bash .patterns/catalog/scripts/install.sh .

# 3. Commit the changes
git add .gitmodules .patterns .github .gitignore
git commit -m "Add Halo-Halo patterns catalog"
```

## What the install script does

- Creates `.patterns/local/cases/` and `.patterns/local/scratch/`
- Copies Halo Copilot prompts/agents to `.github/prompts/halo/` and `.github/agents/halo/`
- Adds `.patterns/local/` to `.gitignore` (idempotent, won't duplicate)
- Creates a README in `.patterns/local/`

## Using Halo patterns

Once installed:

1. Use `/halo-search` in GitHub Copilot Chat to search the catalog
2. Use `/halo-apply` to apply a pattern to your code
3. Use `/halo-gatekeeper` when creating new local patterns

## Updating the catalog

```bash
# Pull latest patterns
git submodule update --remote --merge .patterns/catalog

# Re-run install script if prompts/templates changed
bash .patterns/catalog/scripts/install.sh .
```

## Manual setup (if you prefer)

You can also manually copy files from `templates/consuming/` instead of using the script.
