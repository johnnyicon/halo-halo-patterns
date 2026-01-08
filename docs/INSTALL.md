# Install into a consuming repository

## Quick start

```bash
# 1. Add catalog as submodule
git submodule add https://github.com/johnnyicon/halo-halo-patterns.git .patterns/catalog
git submodule update --init --recursive

# 2. Run install script to wire up templates
bash .patterns/catalog/scripts/install.sh .

# 3. Commit the changes
git add .gitmodules .patterns .github .gitignore
git commit -m "Add Halo-Halo patterns catalog"
```

## What the install script does

- Creates `.patterns/local/cases/` and `.patterns/local/scratch/`
- Copies GitHub Copilot prompts/agents to `.github/`
- Adds `.patterns/local/` to `.gitignore` (idempotent, won't duplicate)
- Creates a README in `.patterns/local/`

## Using patterns

Once installed:

1. Use `/patterns-search` in GitHub Copilot Chat to search the catalog
2. Use `/patterns-apply` to apply a pattern to your code
3. Use `/patterns-gatekeeper` when creating new local patterns

## Updating the catalog

```bash
# Pull latest patterns
git submodule update --remote --merge .patterns/catalog

# Re-run install script if prompts/templates changed
bash .patterns/catalog/scripts/install.sh .
```

## Manual setup (if you prefer)

You can also manually copy files from `templates/consuming/` instead of using the script.
