# Halo-Halo Patterns Catalog

> **Name note:** “Halo” in Filipino/Tagalog means “to mix,” and *halo-halo/haluhalo* means “mixed together.”


This is a starter repo for a vetted programming patterns catalog + deterministic validation tooling + GitHub Copilot prompts/agents.

Key conventions:
- Pattern DB lives in `patterns/` (Markdown + YAML front matter).
- Consuming repos mount the catalog as a submodule at `.patterns/catalog/` and keep `.patterns/local/` as gitignored cases/scratch.
- Copilot prompt files live in `.github/prompts/` and can be invoked as slash commands based on filename.
- Copilot custom agent profiles can live under `.github/agents/`.

See `docs/INSTALL.md` to wire it into a consuming repo.
