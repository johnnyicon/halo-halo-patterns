# Halo-Halo Patterns Catalog

> **Name note:** “Halo” in Filipino/Tagalog means “to mix,” and *halo-halo/haluhalo* means “mixed together.”

A vetted programming patterns catalog designed to work seamlessly with GitHub Copilot.

## What is this?

A collection of reusable patterns, troubleshooting guides, and debugging cases that you can:
- Mount as a Git submodule in any project
- Search via GitHub Copilot Chat prompts
- Use as templates for documenting your own project-specific patterns

## Key conventions:

- **Patterns catalog** lives in `patterns/` (Markdown files with YAML front matter)
- **Consuming repos** mount this as a submodule at `.halo-halo/upstream/`
- **Local patterns** live in `.halo-halo/local/` (gitignored, project-specific)
- **Copilot prompts** in `.github/prompts/` become slash commands
- **Schema and rules** in `schema/` and `rules/` document the pattern format

## Installation

See [`docs/INSTALL.md`](docs/INSTALL.md) for setup instructions.

## Catalog Maintenance

Halo-Halo includes a health check system to ensure patterns stay current and reliable.

### Running Health Checks

**Via Copilot prompt:**
```
/halo-health
```

**Via command line:**
```bash
# From consuming repo root
.halo-halo/upstream/scripts/staleness.sh

# Override staleness threshold (default: 180 days)
MAX_LAST_VERIFIED_DAYS=90 .halo-halo/upstream/scripts/staleness.sh

# Show help
.halo-halo/upstream/scripts/staleness.sh --help
```

**Requirements:**
- Bash
- Python 3 (for date calculations)

**Exit codes:**
- `0` — All checks passed
- `1` — Script error or invalid usage
- `2` — Blocking issues found (overdue reviews, deprecated references)

**What it checks:**
- ✅ Patterns with `review_by` dates in the past (BLOCKING)
- ⚠️ Patterns not verified in `MAX_LAST_VERIFIED_DAYS` (default: 180 days)
- ⚠️ Patterns referencing deprecated patterns
- ℹ️ Statistics (total patterns, review coverage)

## No tooling required

This is a **Markdown-first** catalog. No build steps, no Node.js, no compilation. The patterns are human-readable and LLM-friendly as plain text files.
