---
id: "strip-working-integration-config-anti-pattern"
title: "Anti-Pattern: Stripping Working Integration Config to Fix an Unrelated Bug"
type: anti-pattern
status: validated
confidence: high
revision: 1

languages:
  - language: any
    versions: "*"

frameworks:
  - ecosystem: other
    name: "openclaw"
    version: "*"

dependencies: []
runtime: ["any"]
domain: api-design
tags: ["external-api", "debugging", "additive", "integration", "account-linking", "stripe", "anti-pattern"]

introduced: 2026-03-21
last_verified: 2026-03-21
review_by: 2026-06-21

maintainers: ["@kanekoa"]
deprecated_date: null
superseded_by: null
related: []
sanitized: true
migration_note: null
notes: "Captured after a payment processor Connect debugging session where working account creation params were progressively removed, breaking the entire flow. The actual fix was additive-only (account reuse logic)."
---

# Anti-Pattern: Stripping Working Integration Config to Fix an Unrelated Bug

## Context

When debugging a third-party API integration (payment processor Connect, OAuth, any external account linking), an agent investigates why a newly added feature isn't persisting data correctly. The integration itself was working — the bug is in data routing or persistence, not in the API call parameters.

## Why This Fails

The agent removes API configuration parameters that appear "unnecessary" or poorly understood, trying to simplify the setup. Each removal introduces a new failure mode:

1. `dashboard: "express"` removed → API errors because `dashboard` requires merchant or transfers capability
2. `merchant` config removed → `dashboard` errors, so `dashboard` also gets removed
3. Both removed → account creation produces accounts with no capabilities; the button shows "Starting..." then reverts silently
4. Integration is now completely broken — worse than the original bug

The actual bug had nothing to do with any of these parameters. The bug was: every button click created a new orphaned account, so the DB pointed to account B while the user had onboarded account A.

**Root cause of the anti-pattern:** Confusing "I don't understand why this parameter exists" with "this parameter is causing the bug."

## What To Do Instead

**Diagnose first. Touch nothing that's working.**

1. Read the error carefully — if the symptom is "not connected," check the DB first. Is the account ID saved? Does it match what the user onboarded?
2. Add logging or run a one-off query to confirm data state before changing any code.
3. Make the fix additive: add what's missing, don't remove what's there.
4. If you must remove something, remove exactly one thing, verify the happy path still works, then proceed.

**The correct fix — additive only:**

```go
// BEFORE (broken): creates a new account on every click, orphaning the previous one
account, err := client.CreateAccount(ctx, params)
upsertAccount(userID, account.ID) // overwrites previous account in DB

// AFTER (correct): reuse existing account, create only once
var accountID string
if existing, err := queries.GetAccountByUserID(ctx, userID); err == nil {
    accountID = existing.AccountID // reuse — onboarding continues from where it left off
} else {
    account, err := client.CreateAccount(ctx, params) // create only on first connect
    accountID = account.ID
    upsertAccount(userID, accountID)
}
```

The original API params (merchant config, dashboard setting, capability requests) remain **completely unchanged**.

## Detection

You are falling into this pattern if:

- You are removing API configuration that you didn't write and don't fully understand
- The removal is motivated by "simplification" rather than "this is the proven cause"
- You've made more than one removal in the same debugging session without re-testing between each
- The integration was working before the current bug appeared
- The user has to say "you broke it" — the original problem was simpler than the new problem

## Verification Checklist

- [ ] Root cause confirmed via DB query or logging — not assumed from UI symptoms
- [ ] Fix is purely additive (nothing removed from working API params)
- [ ] Happy path re-tested immediately after any removal before proceeding further
- [ ] Original integration config (capabilities, dashboard, configurations) is unchanged from last working state
- [ ] `git diff` reviewed before deploying — no unexpected deletions
