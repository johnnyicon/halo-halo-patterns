---
id: "go-stale-binary-invisible-fixes"
title: "Go Binaries Must Be Explicitly Rebuilt — Stale Binaries Make Fixes Invisible"
type: troubleshooting
status: validated
confidence: high
revision: 1

languages:
  - language: go
    versions: ">=1.18"

frameworks: []
dependencies: []
domain: development-workflow
tags:
  - go
  - build
  - compiled-language
  - debugging
  - stale-binary
  - invisible-fixes

introduced: 2026-02-22
last_verified: 2026-02-22
review_by: 2026-08-22

maintainers: ["@kanekoa"]
deprecated_date: null
superseded_by: null
related:
  - "go-keyring-test-isolation"
sanitized: true
migration_note: null
notes: "Discovered in Laon Phase 2 live testing. Four bugs were fixed in code, committed, and pushed. All four fixes were invisible because the installed binary was from the day before. The debugging session continued until someone checked the binary mtime."
---

# Go Binaries Must Be Explicitly Rebuilt — Stale Binaries Make Fixes Invisible

## Context

Go is a compiled language. When you change source code, those changes are only present in the running binary after an explicit `go build` (or `go install`). This distinction is easy to forget when working in a workflow where tests run on fresh compiled code (`go test` always compiles before running) but the installed binary is a separate artifact that must be manually rebuilt and reinstalled.

The most dangerous form of this: you fix a bug in source, run `go test ./...` (passes), check the behavior in the running program — and the bug is still there. You assume the fix was wrong. You spend hours debugging a bug that is already fixed, in code that isn't running.

## Symptoms

- Code changes are committed and pushed to git
- `go test ./...` passes (tests run fresh compiled code)
- Running the installed binary shows the old behavior
- Bug appears to persist despite a correct fix being present in source
- Debugging produces no new insights because the code being debugged is not the code being run

## Root Cause

```
Source code (changed)  →  go build  →  Binary (stale)  →  Running program (old behavior)
                                 ↑
                         This step was skipped
```

`git push`, `go test`, IDE reload, and file saves do not update the installed binary. Only `go build` (or `go install`) does.

`go test` compiles a fresh binary for each test run, so tests correctly validate the current source. But the test binary and the installed binary are different artifacts. Passing tests do not mean the installed binary reflects the current source.

## Diagnostic

### Check if the binary is stale

```bash
# When was the binary last built?
ls -la ~/.local/bin/laon          # or wherever your binary lives
ls -la $(which laon)

# Are any source files newer than the binary?
find /path/to/your/project -name '*.go' -newer ~/.local/bin/laon | head -10
```

If `find` returns any files, the source is newer than the binary. The binary is stale. Rebuild before continuing.

### Confirm which binary is running

```bash
which laon
# or
which maykapal

# Confirm it's the one you expect:
ls -la $(which laon)
```

Multiple binaries with the same name in different `$PATH` locations will cause the wrong binary to run. Confirm the full path.

## Fix

Rebuild the binary after any source change:

```bash
# General pattern
go build -o /path/to/binary ./cmd/your-command/

# Laon TUI binary
cd /Users/kanekoa/Workspace/maykapal-os
go build -o ~/.local/bin/laon ./cmd/laon/

# Maykapal CLI binary
cd /Users/kanekoa/Workspace/maykapal-os
go build -o ~/.local/bin/maykapal ./cmd/maykapal/

# Or install to $GOPATH/bin (if that's on $PATH):
go install ./cmd/laon/
```

After rebuilding, verify:

```bash
ls -la ~/.local/bin/laon
# mtime should match now
```

## Prevention

### Before any live testing session

1. Rebuild the relevant binary
2. Verify the binary mtime with `ls -la`
3. Run a quick sanity check before assuming bugs exist

### In CI / automated workflows

Add an explicit build step before integration tests:

```yaml
# Example GitHub Actions step
- name: Build binary
  run: go build -o ./bin/laon ./cmd/laon/

- name: Run integration tests
  run: ./scripts/integration-test.sh
```

### Makefile / just targets

Define explicit build targets to make rebuilding easy:

```makefile
.PHONY: build install

build:
    go build -o ~/.local/bin/laon ./cmd/laon/
    go build -o ~/.local/bin/maykapal ./cmd/maykapal/

install: build
    @echo "Binaries installed to ~/.local/bin/"
```

### The mtime check script

Add this to your debugging checklist:

```bash
#!/bin/bash
# check-binary-freshness.sh
BINARY=$(which laon)
SRCDIR=/Users/kanekoa/Workspace/maykapal-os
STALE=$(find "$SRCDIR" -name '*.go' -newer "$BINARY" | wc -l | tr -d ' ')

if [ "$STALE" -gt "0" ]; then
    echo "⚠️  Binary is stale: $STALE source files newer than $BINARY"
    echo "Run: go build -o $BINARY ./cmd/laon/"
else
    echo "✓ Binary is current"
fi
```

## Tradeoffs

The only tradeoff is a small time cost to rebuild before testing. For a typical Go project, `go build` on changed files takes a few seconds. The cost of debugging with a stale binary can be hours.

**Always rebuild. The few seconds are never the problem.**

## Notes

- This applies to all compiled languages (Rust, C, C++, etc.) — not Go-specific, but Go is particularly prone to this because `go test` creates the illusion of "always running current code"
- The distinction between test binaries and installed binaries is the key insight: `go test` compiles fresh; the installed binary does not auto-update
- If you use `air` or another hot-reload tool during development, this pattern doesn't apply in that context — but be aware that production testing should always use an explicitly-built binary
