---
id: openclaw-subagent-device-scope-repair
title: Sub-agent sessions fail silently with "pairing required" due to missing operator.write scope
type: troubleshooting
status: validated
confidence: high
revision: 1

languages: [shell, yaml]
frameworks:
  - ecosystem: npm
    name: openclaw
    version: ">=2026.2"

runtime: ["macOS", "Linux"]
domain: authorization
tags: ["openclaw", "sub-agents", "sessions_spawn", "device-pairing", "scope", "gateway", "orchestration"]

introduced: 2026-02-20
last_verified: 2026-02-20
review_by: 2026-08-20

maintainers: ["@kanekoa"]
deprecated_date: null
superseded_by: null
related: []
sanitized: true
migration_note: null
notes: "Discovered live during Agent Routing feature improvement session. Affected all sessions_spawn calls across all agents."
---

## Context

Multi-agent orchestration in Maykapal OS (and any OpenClaw setup using `sessions_spawn` with `agentId`) requires the sub-agent process to connect back to the local gateway with `operator.write` scope. If the gateway device used by sub-agents only has `operator.pairing` scope, every spawn silently fails.

**Affected versions:** OpenClaw 2026.2+  
**Trigger:** Device scope degradation — can happen after gateway restarts, re-pairing events, or initial setup where scope was never explicitly granted.

## Symptoms

- `sessions_spawn(agentId="kabu", task="...")` returns immediately with:
  ```
  error: "gateway closed (1008): pairing required"
  ```
- Error appears regardless of which `agentId` is targeted
- `allowAgents: ["*"]` is correctly set on all agents — config looks fine
- `maykapal orchestrate --execute` fails when it shells out to `openclaw agent --json`
- Gateway logs show the real cause:
  ```
  security audit: device access upgrade requested reason=scope-upgrade
  scopesFrom=operator.admin,operator.approvals,operator.pairing
  scopesTo=operator.write
  cause=pairing-required
  ```
- `openclaw devices list` shows the sub-agent device with only `operator.pairing` scope (missing `operator.read` and `operator.write`)

## Root Cause

OpenClaw gateway device auth is scope-based. Sub-agent processes connect to the local gateway WebSocket to use tools (exec, read, browser, etc.). If the device record for the sub-agent process only has `operator.pairing` scope, it cannot perform write operations — which includes spawning sessions, sending messages, and running most agent tools.

The device scope can degrade silently. There is no visible warning in agent behavior; the error surfaces only when `sessions_spawn` is called. The `allowAgents` config and agent-level auth profiles (LLM API keys) are entirely separate from gateway device scope — both can be correctly configured while device scope is missing.

## Fix

**Step 1: Check for pending device requests**
```bash
openclaw devices list
```

Look for the sub-agent device in the `Pending` table with a `repair` flag, and confirm the `Paired` device is missing `operator.write`.

**Step 2: Approve the pending scope-upgrade request**
```bash
openclaw devices approve <requestId>
```

This grants `operator.read`. Re-run `openclaw devices list` to confirm.

**Step 3: Rotate the device to grant full operator write scope**
```bash
openclaw devices rotate \
  --device <deviceId> \
  --role operator \
  --scope operator.admin \
  --scope operator.approvals \
  --scope operator.pairing \
  --scope operator.read \
  --scope operator.write
```

**Step 4: Verify and retry**
```bash
openclaw devices list
# Confirm scopes now include operator.read and operator.write
```

Then retry `sessions_spawn` — it should return `status: "accepted"` instead of the pairing error.

## Verification Checklist

- [ ] `openclaw devices list` shows no `Pending` entries
- [ ] Target device has `operator.read` and `operator.write` in its `Scopes` column
- [ ] `sessions_spawn(agentId="<any>", task="test")` returns `status: "accepted"`
- [ ] Gateway logs show no `pairing-required` errors on next spawn attempt

## Tradeoffs

Granting `operator.write` to the sub-agent device gives it full write access to the gateway. This is expected and required for orchestration — sub-agents need to invoke tools, send messages, and manage sessions. No security regression on a loopback-only gateway.

## Prevention / Detection Gap

There is currently no automated detection for scope degradation. The failure mode is silent from the agent's perspective — agents will report the error but cannot self-diagnose or self-repair. This is a known gap to address in the Agent Routing feature improvement.

**Future fix candidate:** Add a gateway health check step that verifies sub-agent device scopes at startup or before the first `sessions_spawn` call.
