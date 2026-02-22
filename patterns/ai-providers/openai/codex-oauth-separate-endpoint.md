---
id: "pattern-ai-providers-openai-codex-oauth-separate-endpoint"
title: "OpenAI Codex OAuth Tokens Use a Completely Different Endpoint and API Format"
type: architecture
status: draft
confidence: high
revision: 1
languages:
  - language: any
    versions: "*"
frameworks: []
dependencies: []
domain: openai-api
tags:
  - openai
  - codex
  - oauth
  - authentication
  - api
  - ai-providers
introduced: 2026-02-21
last_verified: 2026-02-21
review_by: 2026-05-21
sanitized: true
related:
  - "pattern-ai-providers-anthropic-oauth-token-required-headers"
---

# OpenAI Codex OAuth Tokens Use a Completely Different Endpoint and API Format

## Context

When building a client that supports both standard OpenAI API keys and OAuth tokens from ChatGPT Plus/Pro subscribers, it is tempting to assume both use the same `api.openai.com` endpoint. They do not. OAuth tokens (obtained via the Codex CLI OAuth flow) target a completely separate backend with a different API format, different headers, and different streaming events.

This architectural difference is non-obvious because the OAuth login flow itself (`auth.openai.com`) looks similar to a standard API key setup. The divergence only becomes apparent when you try to use the token.

Source-confirmed from `@mariozechner/pi-ai` npm package (v0.54.0), which is the reference implementation used by OpenClaw.

## Decision

### Two Separate Provider Implementations

OpenAI API key users and ChatGPT Plus/Pro OAuth users require **separate provider implementations** that cannot share the same HTTP client, endpoint, or response parser.

| Attribute | Standard API Key | Codex OAuth (ChatGPT Plus/Pro) |
|-----------|-----------------|-------------------------------|
| Endpoint | `https://api.openai.com/v1/chat/completions` | `https://chatgpt.com/backend-api/codex/responses` |
| Auth | `Authorization: Bearer sk-...` | `Authorization: Bearer <JWT>` |
| Extra headers | None | `chatgpt-account-id`, `OpenAI-Beta`, `originator`, `User-Agent` |
| API format | Chat Completions | OpenAI Responses API |
| SSE events | `delta`, `finish_reason` | `response.completed`, `response.failed`, Codex-specific |

### Required Headers for Codex OAuth

```
Authorization: Bearer <jwt_access_token>
chatgpt-account-id: <chatgpt_account_id>
OpenAI-Beta: responses=experimental
originator: pi
User-Agent: pi (<os> <release>; <arch>)
accept: text/event-stream
content-type: application/json
```

### Extracting the Account ID from the JWT

The `chatgpt-account-id` header value is embedded in the OAuth access token (a JWT). It must be decoded — it is NOT returned separately from the token exchange.

```
JWT payload path: payload["https://api.openai.com/auth"]["chatgpt_account_id"]
```

```go
// Decode JWT (no verification needed — just parsing the payload)
parts := strings.Split(accessToken, ".")
if len(parts) != 3 {
    return "", errors.New("invalid JWT")
}
payload, err := base64.RawURLEncoding.DecodeString(parts[1])
// ...
var claims map[string]interface{}
json.Unmarshal(payload, &claims)
auth := claims["https://api.openai.com/auth"].(map[string]interface{})
accountId := auth["chatgpt_account_id"].(string)
```

### OAuth Login Flow (correct — same as pi-ai)

The login flow itself is identical to what you might expect:

1. Generate PKCE verifier + S256 challenge
2. Build authorization URL at `https://auth.openai.com/oauth/authorize` with:
   - `client_id`, `redirect_uri`, `scope`, `code_challenge`, `code_challenge_method`
   - `state` (random 16-byte hex)
   - `id_token_add_organizations=true`
   - `codex_cli_simplified_flow=true`
   - `originator=pi`
3. Start local HTTP server on **port 1455** (fixed — not random)
4. Open browser to authorization URL
5. Wait for callback at `http://localhost:1455/auth/callback`
6. Exchange code at `https://auth.openai.com/oauth/token` (form-encoded, NOT JSON)
7. Store `access_token`, `refresh_token`, and extracted `chatgpt_account_id`

The Responses API endpoint path resolves to:
```
https://chatgpt.com/backend-api/codex/responses
```
(The base URL `https://chatgpt.com/backend-api` + `/codex/responses`)

### Token Refresh

```
POST https://auth.openai.com/oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&refresh_token=<refresh_token>
&client_id=<client_id>
```

## Tradeoffs

**Benefits:**
- ChatGPT Plus/Pro OAuth enables inference without a paid API account (uses the subscriber's ChatGPT quota)
- Token refresh is automatic — no manual key rotation

**Costs:**
- Requires a completely separate provider implementation — cannot reuse the standard OpenAI provider
- The Codex Responses API format is different from Chat Completions — separate SSE parser required
- `chatgpt-account-id` must be decoded from the JWT at every request (or cached at login time)
- Dependency on `chatgpt.com/backend-api` which is an unofficial/internal endpoint subject to change

## When to Use

- Supporting ChatGPT Plus/Pro subscribers who don't want to pay for API credits separately
- Building a CLI tool that should work with a user's existing ChatGPT subscription
- When standard API key support is already in place and OAuth is being added as a second path

## When NOT to Use

- When only standard API key auth is needed — adds complexity for no benefit
- When building server-side applications (OAuth is designed for interactive CLI/browser flows)
- If you're only targeting API-tier users (enterprise, developers) — standard keys are simpler

## Notes

- The `client_id` for the Codex OAuth app (`app_EMoamEEZ73f0CkXaXp7hrann`) is a shared CLI app registered by OpenAI — the same client ID used by both pi-ai (OpenClaw) and the official Codex CLI
- Port 1455 is **fixed** for the OAuth callback — not configurable. If another process is already listening on 1455, the flow falls back to prompting for manual paste
- The pi-ai reference implementation also supports a fallback where the user manually pastes the redirect URL — useful for headless/SSH environments
- There is also a WebSocket transport option (`wss://chatgpt.com/backend-api/codex/responses`) as an alternative to SSE — same data, different transport
