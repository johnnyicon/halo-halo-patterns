---
id: "mcp-object-schema-missing-properties-openai"
title: "MCP Tool Object Schema Without 'properties' Rejected by OpenAI-Compatible APIs"
type: troubleshooting
status: validated
confidence: high
revision: 1

languages:
  - language: go
    versions: "1.20+"
  - language: any
    versions: "*"

frameworks:
  - ecosystem: go
    name: "go-sdk/mcp"
    version: "any"

dependencies: []
runtime: ["macos", "linux"]
domain: api-design
tags: [mcp, json-schema, openai-compatible, copilot, object-schema, properties, 400-error]

introduced: 2026-03-20
last_verified: 2026-03-20
review_by: 2026-06-20

maintainers: ["@kanekoa"]
deprecated_date: null
superseded_by: null
related: ["mcp-tool-name-dot-notation-breaks-openai-compat"]
sanitized: true
migration_note: null
notes: "Discovered alongside the tool-name dot issue when debugging Copilot CLI 400 errors."
---

# MCP Tool Object Schema Without 'properties' Rejected by OpenAI-Compatible APIs

## Context

MCP tools that take no arguments still require an `InputSchema`. A common shorthand
is to emit a bare `{"type": "object"}` with no `properties` field. This is valid
JSON Schema per the spec but OpenAI-compatible APIs require the `properties` key to
be present (even if empty) when the schema type is `"object"`.

## Symptoms

```
CAPIError: 400 Invalid schema for function '<server>-<tool_name>':
In context=(), object schema missing properties.
```

- Error appears after fixing tool name issues (dots → underscores)
- Affects only tools that take no arguments
- The tool index in the error message points to a "list" or "status" style tool

## Root Cause

A helper that builds input schemas skips the `properties` key when no properties
are defined:

```go
func toolInputSchema(props map[string]interface{}, required []string) map[string]interface{} {
    s := map[string]interface{}{"type": "object"}
    if len(props) > 0 {
        s["properties"] = props  // ← omitted when props is nil
    }
    return s
}
```

This produces `{"type": "object"}` — valid JSON Schema but rejected by OpenAI's
stricter validation which requires `properties` to be an explicit key.

## Fix

Always emit `properties`, even as an empty map:

```go
func toolInputSchema(props map[string]interface{}, required []string) map[string]interface{} {
    s := map[string]interface{}{"type": "object"}
    if len(props) > 0 {
        s["properties"] = props
    } else {
        s["properties"] = map[string]interface{}{}  // ← always present
    }
    if len(required) > 0 {
        s["required"] = required
    }
    return s
}
```

If you're writing schemas inline, always include the key:

```go
// ✅ OpenAI-compatible no-arg schema
InputSchema: map[string]interface{}{
    "type":       "object",
    "properties": map[string]interface{}{},
}
```

## Verification Checklist

- [ ] All no-argument tools produce schemas with `"properties": {}`
- [ ] Copilot CLI or OpenAI client no longer returns "object schema missing properties"
- [ ] `go vet ./...` and tests still pass

## Tradeoffs

None. The fix is strictly additive — Claude and Anthropic's API accept both forms.
