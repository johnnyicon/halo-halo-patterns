---
id: "pattern-ruby-rails-testing-capybara-visible-all-for-opacity-hidden-actions"
title: "Capybara Can’t Click Opacity/Hidden Action Buttons Without visible: :all"
type: troubleshooting
status: draft
confidence: high
revision: 1
languages:
  - language: ruby
    versions: ">=3.0"
frameworks:
  - name: rails
    versions: ">=7.0 <9.0"
dependencies:
  - name: capybara
    versions: ">=3.0"
  - name: selenium-webdriver
    versions: ">=4.0"
domain: testing
tags:
  - capybara
  - system-tests
  - visibility
  - css
  - flaky-tests
introduced: 2026-01-13
last_verified: 2026-01-13
review_by: 2026-04-13
sanitized: true
related: []
---

# Capybara Can’t Click Opacity/Hidden Action Buttons Without `visible: :all`

## Context

In Rails system tests (Capybara + Selenium/Playwright driver), it’s common to render action buttons that are *present in the DOM* but visually hidden until hover/focus. Typical implementations use CSS such as:

- `opacity: 0` (fade in on hover)
- `visibility: hidden` / `pointer-events: none`
- utility classes like `opacity-0`, `invisible`, `sr-only`, etc.

Capybara’s default behavior is to only match **visible** elements. That can cause tests to fail even though the UI is correct in a real browser interaction (hover reveals the button), especially when the test does not trigger the hover state.

## Symptoms

- System test fails to find a button/link that is clearly in the rendered HTML
- Errors like:
  - `Capybara::ElementNotFound` for `click_button` / `click_link`
  - `Unable to find visible css ...`
- Tests pass locally with manual pauses/hover, but fail in CI
- Feature appears correct in browser, but automation can’t click the action

## Root cause

Capybara defaults to matching only visible elements, and “visible” is determined from computed style. Elements with `opacity: 0` or `visibility: hidden` are treated as not visible.

If the UI relies on hover/focus to reveal the button, your test must either:

1) reproduce the hover/focus state, or
2) explicitly allow Capybara to match hidden elements.

## Fix

### Option A (Simple): Use `visible: :all`

When the button is intentionally hidden until hover, allow Capybara to find it anyway:

```ruby
# Example: button exists but is opacity-hidden until hover
find("button", text: "Details", visible: :all).click

# or by CSS selector
find("[data-action='click->controller#method']", visible: :all).click
```

This is usually the lowest-friction fix when the test intent is “click the action”, not “verify hover styling”.

### Option B (Behavior-Accurate): Trigger hover/focus first

If the test intent is to validate the real user interaction, reproduce the hover state:

```ruby
row = find("[data-test='row']")
row.hover
row.click_button("Details")
```

This can be more brittle (driver differences, timing), but it verifies the intended UX.

### Option C (Make actions always visible in test mode)

If hidden actions cause widespread test pain, consider rendering them visible in test environment (or add a test-only class) so tests interact with stable UI.

## Verification checklist

- [ ] Test reliably clicks the action without using sleeps
- [ ] Test passes in CI (headless) as well as locally
- [ ] If using `visible: :all`, confirm the selector is specific enough to avoid clicking the wrong hidden element

## Tradeoffs

- `visible: :all`:
  - ✅ Simple and reliable
  - ✅ Avoids hover timing issues
  - ❌ Can hide real UX regressions if the button becomes unreachable to actual users (e.g., `pointer-events: none`)

- Hover-first:
  - ✅ Validates the actual user interaction
  - ❌ More timing/driver brittle

## References

- Capybara visibility behavior (`visible:` option)
