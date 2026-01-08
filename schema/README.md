# Schema and Rules

These files document the **recommended format** for patterns in this catalog.

- [`schema/pattern.schema.json`](../schema/pattern.schema.json) - JSON Schema defining the YAML front matter structure
- [`rules/lifecycle.json`](../rules/lifecycle.json) - Status lifecycle and validation thresholds
- [`rules/sanitization.json`](../rules/sanitization.json) - Secret detection patterns
- [`rules/gatekeeper.json`](../rules/gatekeeper.json) - Quality checklist for new patterns

## These are documentation, not enforcement

The catalog is **Markdown-first**. These files help you understand what makes a good pattern, but there's no automated validation enforcing them.

When creating patterns:
1. Look at existing patterns for examples
2. Use the templates in `templates/consuming/`
3. Follow the schema as a guide, not a strict requirement

The goal is to keep patterns **useful and searchable by GitHub Copilot**, not to pass linting checks.
