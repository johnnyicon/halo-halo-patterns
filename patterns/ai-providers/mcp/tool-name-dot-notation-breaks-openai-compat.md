---
id: "mcp-tool-name-dot-notation-breaks-openai-compat"
title: "MCP Tool Names with Dots Rejected by OpenAI-Compatible APIs"
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
tags: [mcp, tool-names, openai-compatible, copilot, json-schema, validation, 400-error]

introduced: 2026-03-20
last_verified: 2026-03-20
review_by: 2026-06-20

maintainers: ["@kanekoa"]
deprecated_date: null
superseded_by: null
related: ["mcp-object-schema-missing-properties-openai"]
sanitized: true
migration_note: null
notes: "Discovered when Copilot CLI auto-loaded .mcp.json and rejected all Gomanan MCP tools."
---

# MCP Tool Names with Dots Rejected by OpenAI-Compatible APIs

## Context

MCP servers register tools with a name field. Many implementations use dot notation
as a namespace separator (e.g., `gomanan.bugs_list`, `nomnom.recall`). This works
fine with Claude/Anthropic's API, which accepts dots in tool names.

OpenAI-compatible APIs — including GitHub Copilot, OpenRouter, and any client
following OpenAI's spec — enforce the pattern `^[a-zA-Z0-9_-]+`. Dots are not
allowed.

When a project has an `.mcp.json` pointing to an MCP server, **any** MCP-compatible
client that runs in that directory will load the tools — not just Claude. If those
tools have dots in their names, OpenAI-compatible clients will reject every request
with a 400 error before the LLM can even respond.

## Symptoms

```
CAPIError: 400 Invalid 'tools[N].name': string does not match pattern.
Expected a string that matches the pattern '^[a-zA-Z0-9_-]+'
```

- Every prompt fails immediately, before any tool is called
- Error references a specific tool index (`tools[19]`)
- Happens on first prompt after starting a fresh Copilot/OpenAI client session

## Root Cause

The MCP server registers tool names containing dots (`gomanan.bugs_list`). When the
client connects to the MCP server, it receives the raw registered names and forwards
them to the upstream API. OpenAI's API validates all tool names before processing
any request and rejects the batch if any name is invalid.

Claude Code works because it translates MCP tool names: `gomanan.bugs_list` becomes
`mcp__gomanan__gomanan_bugs_list`. Direct MCP clients (Copilot CLI, OpenAI SDK, etc.)
pass the raw registered name through unchanged.

## Fix

Replace dots with underscores in all MCP tool `Name` registrations:

```go
// Before — breaks OpenAI-compatible clients
sdkmcp.AddTool(server, &sdkmcp.Tool{
    Name: "gomanan.bugs_list",
    ...
})

// After — works with all clients
sdkmcp.AddTool(server, &sdkmcp.Tool{
    Name: "gomanan_bugs_list",
    ...
})
```

**Impact on Claude Code:** None. Claude Code translates both
`gomanan.bugs_list` and `gomanan_bugs_list` to the same exposed name
(`mcp__gomanan__gomanan_bugs_list`). The rename is fully backward-compatible
for Claude sessions.

Update all test files that reference raw tool names by string to match.

## Verification Checklist

- [ ] All `Name:` fields in MCP registration files use only `[a-zA-Z0-9_-]`
- [ ] `grep -r '"[a-zA-Z]*\.[a-zA-Z]' apps/*/cmd/*/mcp_*.go` returns no matches
- [ ] Copilot CLI starts without 400 errors in the project directory
- [ ] Claude Code tool names (via `/tools`) are unchanged from before the rename

## Tradeoffs

- Tool names in logs and traces now use underscores — slightly less readable as
  a namespace separator, but universally compatible
- Test files must be updated to match the new names
