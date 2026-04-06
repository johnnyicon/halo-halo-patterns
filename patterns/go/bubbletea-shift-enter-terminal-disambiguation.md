---
id: "go-bubbletea-shift-enter-terminal-disambiguation"
title: "Bubble Tea Shift+Enter requires CSI u keybinding in terminals that lack Kitty protocol"
type: troubleshooting
status: validated
confidence: high
revision: 1

languages:
  - language: go
    versions: ">=1.22"

frameworks:
  - ecosystem: bubbletea
    name: bubbletea
    version: ">=2.0"

dependencies: []
domain: tui-input
tags:
  - go
  - bubbletea
  - shift-enter
  - kitty-protocol
  - csi-u
  - vscode
  - xterm-js
  - terminal
  - keyboard-disambiguation
  - newline

introduced: 2026-03-09
last_verified: 2026-03-09
review_by: 2026-09-09

maintainers: ["@kanekoa"]
deprecated_date: null
superseded_by: null
related:
  - "go-bubbletea-input-blink-layout-overflow-duplication"
sanitized: true
migration_note: null
notes: "Discovered during Maykapal TUI v2 chat screen. User expected Shift+Enter to insert newlines (like Claude Code webview), but the terminal protocol made it indistinguishable from plain Enter."
---

# Bubble Tea Shift+Enter requires CSI u keybinding in terminals that lack Kitty protocol

## Context

In a Bubble Tea v2 chat TUI, Enter sends a message and Shift+Enter should insert a newline. Bubble Tea v2 requests Kitty keyboard protocol by default, which allows modifier disambiguation (Shift+Enter vs Enter). However, most terminals — including VS Code's integrated terminal (xterm.js) — do not fully support Kitty protocol negotiation, so Shift+Enter arrives as plain Enter with no modifier attached.

This is especially confusing because tools like Claude Code support Shift+Enter, but they run as VS Code webviews (DOM keyboard events with `event.shiftKey`), not terminal processes bound by escape sequence limitations.

## Symptoms

- Pressing Shift+Enter submits the message instead of inserting a newline
- `msg.Mod.Contains(tea.ModShift)` never matches for Enter key
- Alt+Enter works correctly (ESC prefix `\x1b\r` is always distinguishable)
- `cat -v` in the terminal shows identical output for Enter and Shift+Enter
- `tea.KeyboardEnhancementsMsg` may or may not fire depending on terminal

## Root Cause

Three layers contribute:

1. **Terminal protocol limitation**: Without Kitty keyboard protocol, terminals send `\r` (CR, 0x0D) for both Enter and Shift+Enter. The Shift modifier is invisible at the byte level.

2. **VS Code keybinding interference**: VS Code may have existing `shift+enter` keybindings in the `terminalFocus` context that send wrong sequences (e.g., `\\\r\n` which produces a literal backslash + CR + LF).

3. **Bubble Tea v2 byte mapping**: Even when `\n` (LF, 0x0A) is sent for Shift+Enter, Bubble Tea's ultraviolet decoder maps it to `{Code: KeyEnter}` — identical to CR. The legacy key table maps LF to `{Code: 'j', Mod: ModCtrl}` but this path may not be reached in v2's enhanced mode.

The key insight: Bubble Tea v2 checks `KeyEnter` which equals `rune(ansi.CR)` = 0x0D. Both `\r` and `\n` resolve to the same `KeyEnter` code in practice.

## Fix

### 1. VS Code keybinding — send CSI u sequence directly

In VS Code's `keybindings.json` (`Cmd+Shift+P` → "Preferences: Open Keyboard Shortcuts (JSON)"):

```json
{
  "key": "shift+enter",
  "command": "workbench.action.terminal.sendSequence",
  "args": {
    "text": "\u001b[13;2u"
  },
  "when": "terminalFocus"
}
```

This sends the Kitty protocol CSI u encoding: `ESC [ 13 ; 2 u` where:
- `13` = Enter key code (CR)
- `2` = Shift modifier (Kitty modifier encoding: value - 1 = bitmask, so 2 - 1 = 1 = Shift)

Bubble Tea v2's decoder parses this via `kittyKeyMap[13]` → `{Code: KeyEnter}` with `fromKittyMod(1)` → `ModShift`, producing `KeyPressEvent{Code: KeyEnter, Mod: ModShift}`.

### 2. Bubble Tea handler — three-layer catch

```go
case tea.KeyPressMsg:
  switch {
  case msg.Code == tea.KeyEnter && (msg.Mod.Contains(tea.ModShift) || msg.Mod.Contains(tea.ModAlt)):
    // Kitty protocol terminals or Alt+Enter (universal).
    c.input.InsertString("\n")
    return *c, nil
  case msg.String() == "ctrl+j":
    // Fallback: LF (0x0A) mapped to Ctrl+J by legacy decoder.
    c.input.InsertString("\n")
    return *c, nil
  case msg.Code == tea.KeyEnter:
    // Plain Enter → send message.
    // ...
  }
```

This covers:
- **Kitty protocol terminals** (kitty, Ghostty, WezTerm): Shift+Enter arrives with `ModShift`
- **VS Code with CSI u keybinding**: Shift+Enter arrives with `ModShift` via injected sequence
- **Alt+Enter**: Universal fallback, works in all terminals (ESC prefix)
- **Ctrl+J fallback**: Catches LF if a terminal sends 0x0A through the legacy decoder path

### 3. Textarea setup — disable built-in Enter

```go
ta := textarea.New()
ta.KeyMap.InsertNewline.SetEnabled(false) // We handle Enter ourselves.
```

## Why not just use Alt+Enter?

Alt+Enter works universally but is unfamiliar to most users. Shift+Enter is the expected behavior from web-based chat UIs (Slack, ChatGPT, Claude). The CSI u keybinding bridges this expectation gap for VS Code users.

## Verification Checklist

- [ ] Shift+Enter inserts newline (does NOT submit)
- [ ] Plain Enter submits message
- [ ] Alt+Enter inserts newline (fallback)
- [ ] Multi-line messages render correctly after Shift+Enter
- [ ] No stray backslash or other characters appear on Shift+Enter
- [ ] `cat -v` in VS Code terminal shows `^[[13;2u` for Shift+Enter (confirms keybinding active)

## Tradeoffs

- **VS Code keybinding is per-user, not per-project**: Cannot be checked into the repository. Must be documented or distributed via onboarding scripts.
- **CSI u injection bypasses terminal negotiation**: The sequence works because Bubble Tea's decoder always parses valid CSI u, regardless of whether Kitty protocol was negotiated. This is an assumption that could break if a future Bubble Tea version gates CSI u parsing behind negotiation.
- **Other terminals need their own configuration**: iTerm2, Terminal.app, Alacritty — each has its own way to remap Shift+Enter. The CSI u sequence `\x1b[13;2u` is the universal target.

## Terminal-Specific Configuration

| Terminal | Shift+Enter Support | Configuration |
|----------|---------------------|---------------|
| VS Code (xterm.js) | Keybinding required | `keybindings.json` with `\u001b[13;2u` |
| kitty | Native | Works out of the box (Kitty protocol) |
| Ghostty | Native | Works out of the box |
| WezTerm | Native | Works out of the box |
| iTerm2 | Profile setting | Keys → Key Mappings → Send Escape Sequence |
| Terminal.app | Not supported | Use Alt+Enter fallback |
| Alacritty | Config required | `key_bindings` in `alacritty.toml` |

## References

- [Kitty keyboard protocol spec](https://sw.kovidgoyal.net/kitty/keyboard-protocol/)
- [CSI u encoding](https://www.leonerd.org.uk/hacks/fixterms/) — the original proposal
- [Bubble Tea v2 upgrade guide](https://github.com/charmbracelet/bubbletea/blob/main/UPGRADE_GUIDE_V2.md)
- [VS Code terminal.sendSequence](https://code.visualstudio.com/docs/terminal/advanced#_send-a-sequence)
- `charm.land/bubbletea/v2` decoder: `ultraviolet/decoder.go` lines 1200-1450 (kittyKeyMap + CSI u parser)
