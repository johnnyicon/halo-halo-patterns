---
id: "macos-xattr-provenance-sigkill-binary"
title: "macOS com.apple.provenance xattr Causes SIGKILL on Copied Binaries"
type: troubleshooting
status: validated
confidence: high
revision: 1

languages:
  - language: go
    versions: "1.20+"
  - language: any
    versions: "*"

frameworks: []

dependencies: []
runtime: ["macos"]
domain: deployment
tags: [macos, xattr, sigkill, binary, deploy, provenance, gatekeeper, anito]

introduced: 2026-03-20
last_verified: 2026-03-20
review_by: 2026-06-20

maintainers: ["@kanekoa"]
deprecated_date: null
superseded_by: null
related: []
sanitized: true
migration_note: null
notes: "Discovered during Anito deploy of gomanan-daemon after a failed health check left the service in a restart loop."
---

# macOS com.apple.provenance xattr Causes SIGKILL on Copied Binaries

## Context

When deploying compiled binaries on macOS by copying them (`cp`, `rsync`, etc.)
from one path to another, macOS may attach extended attributes — including
`com.apple.provenance` — that cause the OS to SIGKILL the process immediately
on execution. This manifests as a silent crash with exit code 137 (128 + SIGKILL)
before the process can write a single log line.

The behavior is path-sensitive: the same binary content works from the source path
(`~/go/bin/`) but is killed from the destination path (`.anito/`). This makes
debugging extremely confusing — `md5` shows identical content, `file` shows the
same architecture, but execution behavior differs by path.

## Symptoms

- `go run ./cmd/...` works perfectly
- The installed binary at `~/go/bin/<name>` works (e.g., `<binary> version` exits 0)
- The copied binary at the deploy destination exits 137 immediately
- No log output whatsoever — not even the first `log.Printf` in `main()`
- Service manager (e.g., Anito) reports "health check timed out" with no log evidence
- `xattr -l <binary>` shows `com.apple.provenance:` with an empty value

## Root Cause

macOS tracks binary provenance through extended attributes. When a binary is copied
to a new path, macOS can set `com.apple.provenance` on the copy. Depending on
system security policy, this attribute may cause the OS to kill the process before
it can execute — effectively acting as an ad-hoc quarantine without the more visible
`com.apple.quarantine` flag.

The attribute is set on the file at the destination path, not derived from content,
which is why the same binary content works from the source path and not the
destination.

## Fix

Clear all extended attributes after every copy:

```bash
cp ~/go/bin/<binary> /path/to/deploy/<binary>
xattr -c /path/to/deploy/<binary>
```

For automated build/deploy steps, include both commands:

```yaml
# .anito/service.yaml
build: >
  go install ./cmd/<binary>/ &&
  cp ~/go/bin/<binary> /path/to/deploy/<binary> &&
  xattr -c /path/to/deploy/<binary>
```

## Verification Checklist

- [ ] `xattr -l /path/to/deploy/<binary>` returns no output after `xattr -c`
- [ ] `/path/to/deploy/<binary> version` (or `--help`) exits 0
- [ ] Service manager health check passes on next deploy

## Tradeoffs

- `xattr -c` removes ALL extended attributes, including any intentionally set ones.
  For standard compiled binaries with no custom xattrs, this is always safe.
- Must be re-run after every `cp` — automate it in the build step, not as a one-off fix.
