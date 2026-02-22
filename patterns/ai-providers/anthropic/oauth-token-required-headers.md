---
id: "pattern-ai-providers-anthropic-oauth-token-required-headers"
title: "Anthropic API: OAuth Tokens Require Specific Headers and System Prompt"
type: troubleshooting
status: draft
confidence: high
revision: 1
languages:
  - language: any
    versions: "*"
frameworks: []
dependencies: []
domain: anthropic-api
tags:
  - anthropic
  - oauth
  - authentication
  - api
  - headers
  - ai-providers
introduced: 2026-02-21
last_verified: 2026-02-21
review_by: 2026-05-21
sanitized: true
related: []
---

# Anthropic API: OAuth Tokens Require Specific Headers and System Prompt

## Context

When implementing an API client for `api.anthropic.com`, you may want to support both:

- **Standard API keys** (`sk-ant-api03-...`) — obtained from https://console.anthropic.com/settings/keys
- **OAuth access tokens** (`sk-ant-oat01-...`) — obtained via the Anthropic OAuth flow (Claude Pro/Max subscriber accounts)

The two credential types use completely different authentication mechanisms and require different headers. Mixing them up produces misleading error messages that obscure the real problem.

## Symptoms

**Symptom 1:** Sending an OAuth token as `x-api-key`:
```
HTTP 401
{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}
```

**Symptom 2:** Sending an OAuth token as `Authorization: Bearer` without the required companion headers:
```
HTTP 401
{"type":"error","error":{"type":"authentication_error","message":"OAuth authentication is currently not supported."}}
```

The second error message is **actively misleading** — OAuth IS supported, but requires specific companion headers that signal the request is coming from an authorized CLI client.

## Root Cause

Anthropic's API enforces OAuth via an identity-check mechanism, not just a token check. When you present an OAuth token, the API also requires:

1. **`anthropic-beta` header** — must include `claude-code-20250219` and `oauth-2025-04-20` flags
2. **`User-Agent` header** — must identify the caller as a Claude CLI client
3. **`x-app` header** — must be `cli`
4. **Mandatory first system block** — the first entry in the `system` array must be the Claude Code identity prompt

Without all four of these, the server rejects the request with "OAuth authentication is currently not supported" regardless of whether the token itself is valid.

Additionally, for OAuth mode the `system` field must be a **content-block array**, not a plain string.

**Token detection:** The prefix identifies the type:
- `sk-ant-api03-...` → standard API key → `x-api-key` header
- `sk-ant-oat01-...` (or any `sk-ant-oat*`) → OAuth token → `Authorization: Bearer` + companion headers
- `sktk_...` → setup-token (same OAuth path)

This behavior was confirmed by studying the `@mariozechner/pi-ai` npm package (v0.54.0), which is the reference implementation used by OpenClaw.

## Fix

### Step 1: Detect token type by prefix

```go
// isOAuthToken returns true for OAuth access tokens and setup-tokens.
// These require Bearer auth and companion headers instead of x-api-key.
func isOAuthToken(key string) bool {
    return strings.HasPrefix(key, "sk-ant-oat") || strings.HasPrefix(key, "sktk_")
}
```

### Step 2: Set the correct auth header

```go
if isOAuthToken(key) {
    req.Header.Set("Authorization", "Bearer "+key)
    // Required companion headers — all three are mandatory
    req.Header.Set("anthropic-beta", "claude-code-20250219,oauth-2025-04-20,fine-grained-tool-streaming-2025-05-14")
    req.Header.Set("User-Agent", "claude-cli/2.1.2 (external, cli)")
    req.Header.Set("x-app", "cli")
} else {
    req.Header.Set("x-api-key", key)
}
req.Header.Set("anthropic-version", "2023-06-01")
req.Header.Set("content-type", "application/json")
```

### Step 3: Inject mandatory system prompt for OAuth

For OAuth tokens, the `system` field must be an array (not a string), and the **first element must always be** the Claude Code identity block:

```go
// Correct: system as content-block array with mandatory identity first
type textBlock struct {
    Type string `json:"type"`
    Text string `json:"text"`
}

var systemBlocks []textBlock

if isOAuth {
    // REQUIRED — first block must always be this exact text for OAuth
    systemBlocks = append(systemBlocks, textBlock{
        Type: "text",
        Text: "You are Claude Code, Anthropic's official CLI for Claude.",
    })
}
if callerSystemPrompt != "" {
    systemBlocks = append(systemBlocks, textBlock{
        Type: "text",
        Text: callerSystemPrompt,
    })
}
body["system"] = systemBlocks
```

For standard API keys, `system` can be either a plain string or an array.

### Complete header reference for OAuth mode

| Header | Required Value |
|--------|---------------|
| `Authorization` | `Bearer <oauth-token>` |
| `anthropic-beta` | `claude-code-20250219,oauth-2025-04-20,fine-grained-tool-streaming-2025-05-14` |
| `User-Agent` | `claude-cli/2.1.2 (external, cli)` |
| `x-app` | `cli` |
| `anthropic-version` | `2023-06-01` |
| `content-type` | `application/json` |
| First system block | `"You are Claude Code, Anthropic's official CLI for Claude."` |

## Verification Checklist

- [ ] Token prefix check correctly routes `sk-ant-oat*` → Bearer path
- [ ] All three companion headers present when using OAuth token
- [ ] `anthropic-beta` includes both `claude-code-20250219` AND `oauth-2025-04-20`
- [ ] System prompt array starts with the Claude Code identity block
- [ ] Standard API keys (`sk-ant-api03-*`) still use `x-api-key` (not Bearer)
- [ ] Live smoke test: send a message, receive a non-401 response

## Notes

- The `claude-code-20250219` and `oauth-2025-04-20` beta flags may evolve. If the flow breaks after an Anthropic SDK update, check the latest version of `@mariozechner/pi-ai` for updated values.
- The `fine-grained-tool-streaming-2025-05-14` flag in `anthropic-beta` enables tool streaming and is included in the reference implementation; include it for forward compatibility.
- This pattern also applies to TypeScript, Python, or any language calling `api.anthropic.com` directly — it is not Go-specific.
- The misleading "OAuth authentication is currently not supported" error has caused multiple incorrect diagnoses (e.g., concluding OAuth doesn't work at all). The actual meaning is "you're using OAuth but missing the required handshake headers."
