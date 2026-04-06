---
id: "go-bubbletea-input-blink-layout-overflow-duplication"
title: "Bubble Tea input line duplicates infinitely when cursor blink meets unstable panel heights"
type: troubleshooting
status: validated
confidence: high
revision: 1

languages:
  - language: go
    versions: ">=1.22"

frameworks:
  - ecosystem: bubbletea
    name: bubbles/textinput
    version: ">=0.18"

dependencies: []
domain: tui-rendering
tags:
  - go
  - bubbletea
  - bubbles
  - textinput
  - cursor-blink
  - layout
  - height-overflow
  - rendering
  - duplication

introduced: 2026-02-24
last_verified: 2026-02-24
review_by: 2026-08-24

maintainers: ["@kanekoa"]
deprecated_date: null
superseded_by: null
related:
  - "go-stale-binary-invisible-fixes"
sanitized: true
migration_note: null
notes: "Discovered during Maykapal TUI V2 refactor after introducing root shell + routed screens. Symptom looked like input value being copied to a new line repeatedly and pushing the UI upward."
---

# Bubble Tea input line duplicates infinitely when cursor blink meets unstable panel heights

## Context

In a composed Bubble Tea UI (root shell + nested screen + multiple bordered panes), `bubbles/textinput` cursor blinking can trigger periodic re-renders. If total rendered output height is not perfectly stable on each render, the terminal can scroll instead of redraw, making it appear as if the input line is duplicated over and over.

This is especially easy to trigger after refactors that split one monolithic view into nested components with independent height math.

## Symptoms

- Typing in input works, but the current input line appears duplicated repeatedly
- UI seems to "push upward" on a loop
- Duplication continues even when idle (cursor blink cadence)
- Disabling input update/blink immediately stops the issue
- The sidebar may appear full-height while adjacent panes are shorter/misaligned

## Root Cause

Two conditions combined:

1. `textinput.Blink` produces periodic update messages (cursor visibility toggle)
2. Layout output was not strictly height-stable across renders

When any pane's rendered height fluctuates or total composed output exceeds terminal height, Bubble Tea alt-screen redraw can degrade into visible scroll behavior.

Even a 1-line mismatch in composed panel heights is enough to produce the "infinite duplicate input" effect.

## Diagnostic Pattern

1. **Smoke test:** disable input update/blink temporarily
   - If duplication stops, blink-driven re-render path is implicated
2. **Check panel height contracts**
   - Every bordered panel should have explicit `.Height(...)`
   - Verify total rows for root view <= terminal rows
3. **Check nested composition math**
   - Root shell height budget vs child screen height budget
   - Bordered panels add 2 rows (top+bottom)
4. **Check resize flow**
   - Avoid forwarding raw `WindowSizeMsg` to child after already applying adjusted dimensions

## Fix Applied (Maykapal)

- Disabled blink loop for stability in current phase:
  - Removed `textinput.Blink` from session screen `Init()`
  - Processed input updates but discarded returned blink cmd
- Stabilized panel contracts:
  - Explicit fixed heights for input/chat/session panels
  - Root view hard-truncated to terminal height as a safety rail
- Corrected resize routing:
  - Root applies adjusted dimensions once; does not re-forward raw window size that overwrites child width/height

## Minimal Safe Workaround

If blocked and need immediate stability:

```go
// Init: don't start blink timer
return tea.Batch(loadCmds...)

// Update: keep typing, discard blink cmd
input, _ = input.Update(msg)
```

This removes blinking cursor but preserves typing behavior and prevents runaway redraw loops.

## Long-term Correct Fix

- Keep blink enabled only when layout contracts are mathematically stable
- Enforce strict height budgets in one place (root), then pass deterministic content bounds to children
- Add rendering invariants/tests:
  - fixed line count for representative states
  - no frame exceeds terminal dimensions for same window size

## Prevention Checklist

- [ ] Every bordered pane has explicit `.Height(...)`
- [ ] Root + nested panes share one authoritative height budget
- [ ] No duplicate resize application (adjusted + raw)
- [ ] Input blink enabled only after layout stability verified
- [ ] Smoke test includes idle wait (5–10s) to catch blink-loop regressions

## Tradeoffs

Disabling blink is UX regression (static cursor), but a valid stabilization move while refactoring layout architecture.

Prefer a static cursor over a broken terminal session that appears to duplicate user input infinitely.
