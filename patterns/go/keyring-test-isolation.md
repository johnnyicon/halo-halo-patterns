---
id: "go-keyring-test-isolation"
title: "Go OS Keyring Leaks Into Tests When Helper Constructors Override Only the File Path"
type: troubleshooting
status: validated
confidence: high
revision: 1

languages:
  - language: go
    versions: ">=1.21"

frameworks:
  - ecosystem: go
    name: go-keyring
    version: ">=1.2"

runtime: ["macOS", "Linux", "Windows"]
domain: testing
tags:
  - go
  - keyring
  - os-keyring
  - test-isolation
  - auth
  - store
  - credential-leak

introduced: 2026-02-22
last_verified: 2026-02-22
review_by: 2026-08-22

maintainers: ["@kanekoa"]
deprecated_date: null
superseded_by: null
related:
  - "pattern-ai-providers-anthropic-oauth-token-required-headers"
sanitized: true
migration_note: null
notes: "Discovered in Laon Phase 2 testing. A test wrote 'still-valid' mock token to real macOS Keychain. Runtime app read mock token, sent to Anthropic API, got misleading 401 'invalid x-api-key' error that looked like a header bug."
---

# Go OS Keyring Leaks Into Tests When Helper Constructors Override Only the File Path

## Context

When building an auth store that writes credentials to both the OS keychain and a fallback file, it is common to provide a test-friendly constructor that accepts a custom file path (e.g., pointing at a `t.TempDir()`). This feels like proper test isolation — the store writes to a temp directory that gets cleaned up after the test.

**The trap:** if the test constructor still instantiates the real OS keyring alongside the custom file path, every `Set*` call in the test writes to both — including the real, persistent keychain. The temp file gets cleaned up; the keychain entry does not.

The result is a poisoned keychain that affects every subsequent run of the real application, causing authentication failures with symptoms that look completely unrelated to test isolation.

## Symptoms

**In the test run:** Tests pass. No errors. The keychain write happens silently.

**In the real application (after tests):** Authentication fails with an error that matches a *different* known bug — for example, if the poisoned token is `"still-valid"` and is used as a Bearer token, Anthropic returns:

```
HTTP 401
{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}
```

This error looks like an auth header routing bug (OAuth token sent as `x-api-key`), not a test isolation issue. It causes the team to chase the wrong root cause.

**Diagnostic:** Run the real application's auth resolution and inspect the raw credential source. If the credential value is obviously fake (`"still-valid"`, `"test-token"`, `"mock-key"`), the keychain has been poisoned by a test.

## Root Cause

```go
// ❌ Problematic: custom path but real keyring
func newAutoStoreAt(path string) *AutoStore {
    return &AutoStore{
        keyring: NewKeyringStore(), // ← real OS keychain — never isolated!
        file:    NewFileStoreAt(path), // ← custom path — isolated to temp dir
    }
}
```

When a test calls `store.SetAnthropic(mockCreds)`:

1. `as.keyring.SetAnthropic(mockCreds)` → writes `"still-valid"` to **real OS keychain** ✗
2. `as.file.SetAnthropic(mockCreds)` → writes to `t.TempDir()` → cleaned up after test ✓

At test teardown, the file is gone. The keychain entry persists indefinitely.

At runtime, `AutoStore.GetAnthropic()` reads keychain first (keychain-first policy), finds the mock token, and returns it as real credentials.

## Fix

### Step 1: Extract a keyring interface

```go
// keyringBackend abstracts the OS keychain so tests can use a no-op.
type keyringBackend interface {
    GetOpenAI(ctx context.Context) (Credentials, error)
    GetAnthropic(ctx context.Context) (Credentials, error)
    SetOpenAI(sp StoredProvider) error
    SetAnthropic(sp StoredProvider) error
    DeleteOpenAI() error
    DeleteAnthropic() error
}
```

### Step 2: Add a no-op implementation

```go
// noopKeyringStore is a keyringBackend that never reads or writes the real OS keychain.
// Use this in test helpers — it keeps all credential I/O in the FileStore only.
type noopKeyringStore struct{}

func (n *noopKeyringStore) GetOpenAI(_ context.Context) (Credentials, error) {
    return Credentials{}, fmt.Errorf("keyring: noop")
}
func (n *noopKeyringStore) GetAnthropic(_ context.Context) (Credentials, error) {
    return Credentials{}, fmt.Errorf("keyring: noop")
}
func (n *noopKeyringStore) SetOpenAI(_ StoredProvider) error    { return nil }
func (n *noopKeyringStore) SetAnthropic(_ StoredProvider) error { return nil }
func (n *noopKeyringStore) DeleteOpenAI() error                  { return nil }
func (n *noopKeyringStore) DeleteAnthropic() error               { return nil }
```

### Step 3: Use noop in the test helper constructor

```go
// ✅ Correct: noop keyring — all I/O goes to the isolated FileStore
func newAutoStoreAt(path string) *AutoStore {
    return &AutoStore{
        keyring: &noopKeyringStore{},    // ← noop — never touches OS keychain
        file:    NewFileStoreAt(path),   // ← isolated to temp dir
    }
}
```

### Step 4: Change AutoStore to use the interface

```go
type AutoStore struct {
    keyring keyringBackend // was *KeyringStore — now accepts both real and noop
    file    *FileStore
}
```

### Step 5: Clear any already-poisoned keychain entry

If you suspect the keychain has been poisoned, delete the entry directly:

```go
// One-time cleanup test (delete after running):
import "github.com/zalando/go-keyring"

err := keyring.Delete("your-service-name", "provider-name") // e.g. "maykapal", "anthropic"
```

Or via system UI: Keychain Access (macOS) → search for your service name → delete.

## Verification Checklist

- [ ] `newAutoStoreAt()` (or equivalent test helper) uses `noopKeyringStore`, not `NewKeyringStore()`
- [ ] `AutoStore.keyring` field is declared as the interface type, not the concrete type
- [ ] Tests that call `store.Set*()` do not leave entries in the real keychain (verify with Keychain Access / `security` CLI on macOS)
- [ ] Real application auth resolves live credentials after clearing any poisoned entries
- [ ] `go test ./...` passes and does not write to the system keychain

## Prevention

Add this to your project's test authoring guidelines:

> **Never use `NewRealKeyring()` in test helper constructors that accept a custom path.** If your store has a "partial override" constructor (e.g., overriding only the file path), ensure ALL backends in that constructor use test doubles.

A secondary safeguard: run integration tests against a mock keychain library (e.g., set `KEYRING_BACKEND=file` if your library supports it) to catch this class of bug in CI before it affects developer machines.

## Tradeoffs

The `noopKeyringStore` pattern means tests only exercise the file path of the store. This is intentional — the keyring path is exercised separately in tests that explicitly test `KeyringStore` behavior. Mixing them in unit tests causes exactly the contamination described here.
