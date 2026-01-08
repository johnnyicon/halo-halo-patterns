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
- **Consuming repos** mount this as a submodule at `.patterns/catalog/`
- **Local patterns** live in `.patterns/local/` (gitignored, project-specific)
- **Copilot prompts** in `.github/prompts/` become slash commands
- **Schema and rules** in `schema/` and `rules/` document the pattern format

## Installation

See [`docs/INSTALL.md`](docs/INSTALL.md) for setup instructions.

## No tooling required

This is a **Markdown-first** catalog. No build steps, no Node.js, no compilation. The patterns are human-readable and LLM-friendly as plain text files.
