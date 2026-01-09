# Halo-Halo Patterns Changelog

All notable changes to Halo-Halo Patterns will be documented in this file.

**Format:** Each version includes human-readable description AND LLM-actionable instructions.

**Versioning:** [Semantic Versioning](https://semver.org/)
- **Major:** Breaking changes (file structure changed, API changed)
- **Minor:** New features (new prompts, agents, patterns)
- **Patch:** Fixes (typos, improved wording, bug fixes)

---

## [Unreleased]

### Added
- Health check system for catalog maintenance
  - `/halo-health` prompt for auditing pattern freshness via Copilot
  - `scripts/staleness.sh` for command-line health checks
  - Checks for overdue reviews (BLOCKING), stale patterns (WARNING), deprecated references
  - `--help` flag with usage documentation
  - Python 3 availability check with clear error message
- Verification script now checks health check components (halo-health.prompt.md, staleness.sh executable, Python 3)
- Instructions snippet now documents `/halo-health` command
- README now includes "Catalog Maintenance" section with health check usage

### Fixed
- Install script now selectively copies only prompts, agents, and workflows (not snippet file)
- Verify script no longer checks for snippet file in consuming repo
- Agent tool names corrected: `repo_read` → `read_file`, `repo_search` → `semantic_search`

---

## [0.1.0] - 2026-01-08

### Added
- Initial release of Halo-Halo Patterns catalog
- Install script for consuming repositories
- Verification script for validating installation
- Halo-Gatekeeper agent for capturing patterns
- Halo-Search prompt for finding patterns
- Halo-Apply prompt for applying patterns
- Halo-Install-Wizard prompt for guided setup
- Instructions snippet for Copilot integration
- CI workflow for pattern validation
- **Action:** Run `bash .halo-halo/upstream/scripts/install.sh .` to install

### Changed
- N/A (initial release)

### Fixed
- N/A (initial release)

---

## Release History

| Version | Date | Summary |
|---------|------|---------|
| 0.1.0 | 2026-01-08 | Initial release |
