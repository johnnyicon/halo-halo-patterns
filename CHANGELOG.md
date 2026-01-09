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

### Changed

### Fixed

---

## [0.1.1] - 2026-01-08

### Fixed
- **CRITICAL:** Install script now places agents in root `.github/agents/` folder (not `agents/halo/` subfolder)
  - VS Code doesn't support agent subfolders - agents must be in root agents directory
  - Updated `scripts/install.sh` to copy agents to `.github/agents/` instead of `.github/agents/halo/`
  - Updated `scripts/verify.sh` to check for agent at correct path
  - Updated `halo-install-wizard.prompt.md` documentation to reflect correct paths
  - **Action for existing installations:** Move `.github/agents/halo/halo-gatekeeper.agent.md` to `.github/agents/halo-gatekeeper.agent.md` and remove empty `halo/` folder

### Added
- `/halo-write-pattern` prompt for writing pattern files from Gatekeeper decisions
  - Supports both local case files (`.halo-halo/local/cases/`) and upstream pattern drafts
  - Comprehensive templates for troubleshooting, implementation, anti-pattern, and architecture patterns
  - Sanitization rules and verification checklists
  - Step-by-step workflow guidance
- `/halo-commit` prompt for safely committing pattern artifacts with validation
  - Pre-commit checks: staleness script, sanitization scans, metadata verification
  - Separate workflows for local cases vs upstream patterns
  - Submodule commit workflow with pointer update
  - Error handling guidance for common issues
  - Comprehensive verification checklist
  - Generates safe git commands (does not run them automatically)
- Workflow documentation: Gatekeeper (decides) → Writer (executes) → Commit (validates)
- Health check system for catalog maintenance
  - `/halo-health` prompt for auditing pattern freshness via Copilot
  - `scripts/staleness.sh` for command-line health checks
  - Checks for overdue reviews (BLOCKING), stale patterns (WARNING), deprecated references
  - `--help` flag with usage documentation
  - Python 3 availability check with clear error message
- Verification script now checks health check components (halo-health.prompt.md, staleness.sh executable, Python 3)
- Instructions snippet now documents `/halo-health` and `/halo-write-pattern` commands
- README now includes "Catalog Maintenance" section with health check usage

### Changed
- Install script now selectively copies only prompts, agents, and workflows (not snippet file)
- Verify script no longer checks for snippet file in consuming repo
- Agent tool names corrected: `repo_read` → `read_file`, `repo_search` → `semantic_search`
- Install script uses file-based awk to avoid newline issues in snippet merge

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
| 0.1.1 | 2026-01-08 | Fix agent installation path (critical bugfix) |
| 0.1.0 | 2026-01-08 | Initial release |
