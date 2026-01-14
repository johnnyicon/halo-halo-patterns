---
id: "pattern-ruby-rails-hotwire-async-controller-initialization-race"
title: "Event Race Condition When Portal Renders Async in Stimulus"
type: troubleshooting
status: validated
confidence: high
revision: 3
languages:
  - language: ruby
    versions: ">=3.0"
  - language: javascript
    versions: ">=ES2015"
frameworks:
  - name: rails
    versions: ">=7.0 <9.0"
  - name: hotwire
    versions: ">=1.0"
  - name: stimulus
    versions: ">=3.0"
dependencies: []
domain: hotwire
tags:
  - stimulus
  - async
  - race-condition
  - initialization
  - events
  - portals
  - shadcn
  - radix-ui
introduced: 2026-01-12
last_verified: 2026-01-13
review_by: 2026-04-13
sanitized: true
related:
  - pattern-ruby-rails-hotwire-portal-state-detection-stimulus
  - pattern-ruby-rails-views-duplicate-template-feature-inconsistency
---

# Event Race Condition When Portal Renders Async in Stimulus

## Context

In Stimulus applications, when one controller dispatches events that another controller must listen for, a race condition occurs if the listening controller initializes asynchronously (e.g., portal rendering, lazy loading, dynamic imports).

**This pattern applies when:**
- Controller A dispatches custom events (e.g., `drawer:open`)
- Controller B listens for those events
- Controller B initializes asynchronously (portal rendering, lazy load, dynamic import)
- Event fires before listener is attached → event lost

**Preconditions:**
- Multiple Stimulus controllers communicating via custom DOM events
- At least one controller has async initialization (portal rendering most common)
- Event dispatch happens immediately after user action
- No guarantee of initialization order

## Symptoms

**Observable Behavior:**

1. **Button click does nothing (no error thrown):**
```javascript
// User clicks "Open Drawer" button
// Button controller dispatches drawer:open event
// But drawer controller hasn't finished initializing
// Event fires → no listener → nothing happens
```

2. **Feature works inconsistently:**
- Works on second click (controller now initialized)
- Works if you wait a moment before clicking
- Works in tests (timing different from real browser)
- Fails on first interaction after page load

3. **Console shows event dispatched but not received:**
```javascript
// Dispatching controller
console.log('Dispatching drawer:open'); // Logged

// Listening controller
this.element.addEventListener('drawer:open', ...); // Never attached yet
```

**Real-world symptom:**
User clicks "View Details" button. Drawer opens (portal animation works) but content doesn't load. Second click works fine.

## Root Cause

**Technical Explanation:**

Portal rendering (and other async component initialization) is **asynchronous**, but event dispatch is **synchronous**. This creates a race condition:

```javascript
// Timeline of what happens:

// T=0ms: Page loads
// T=10ms: Button controller connects (synchronous)
// T=20ms: User clicks button
// T=20ms: Button dispatches 'drawer:open' event (synchronous)
// T=30ms: Portal starts rendering drawer (async)
// T=50ms: Drawer controller connects (async - TOO LATE!)
// T=50ms: Drawer controller adds event listener (event already fired at T=20ms)
```

**The race:**
1. Button controller connects immediately (synchronous Stimulus lifecycle)
2. Button dispatches event on click (synchronous event dispatch)
3. Drawer starts rendering in portal (async - React/browser scheduling)
4. Drawer controller connects AFTER event already fired
5. Event listener never receives the event (event doesn't wait)

**Why no error:**
DOM event dispatch is silent if no listeners exist. No error thrown, no warning logged.

**Why it works on second click:**
By the time user clicks again, drawer controller has connected and listener is attached.

## Fix

### Solution: Synchronous Flag + Async Event + Fallback Timeout

Use three synchronization mechanisms to cover all timing scenarios:

**Pattern:**

### Architectural Fix (Often Best): Remove the Async Initialization Point

The `__*Ready` + `*:ready` event + timeout pattern is a good mitigation when you *must* keep an async initialization boundary (most commonly: portal-based UI). However, if you control the UI architecture, the most reliable fix is to eliminate the race condition entirely.

**Approach:** Render the “listening” controller synchronously in the initial DOM (inline, non-portal). For example, instead of rendering a drawer/sheet via a portal, render an inline “details pane” that is always present but toggled with local state (e.g., `.hidden`).

**Why this works:**
- The listener controller connects during normal page load, before the first interaction.
- There is no dependency on portal timing, animation scheduling, or delayed DOM insertion.
- You can often remove `window.__*Ready` flags and timeout fallbacks because the listener is always present.

**Rule of thumb:**
- If the UI element is always in the DOM (just hidden), you generally do **not** need readiness flags.
- If the UI element is injected later (portal, lazy load, Turbo Stream insertion), keep the readiness pattern.

```javascript
// Drawer Controller (initializing controller)
export default class extends Controller {
  connect() {
    // 1. Synchronous flag (for immediate checks)
    window.__drawerReady = true;
    
    // 2. Async event (for event listeners)
    this.dispatch('ready', { detail: { controller: 'drawer' } });
    
    console.log('Drawer controller ready');
  }
}

// Button Controller (waiting controller)
export default class extends Controller {
  async open() {
    // Wait for drawer to be ready using three paths
    await Promise.race([
      // Path 1: Immediate return if flag already set
      ...(window.__drawerReady ? [Promise.resolve()] : []),
      
      // Path 2: Wait for async event
      new Promise(resolve => 
        window.addEventListener('drawer:ready', resolve, { once: true })
      ),
      
      // Path 3: Timeout fallback (graceful degradation)
      new Promise(resolve => setTimeout(resolve, 500))
    ]);
    
    // Now safe to open drawer (controller guaranteed to be initialized)
    this.openDrawer();
  }
}
```

### Step-by-Step Implementation

**Step 1: Identify async initialization points**

Look for:
- Portal-rendered components (Shadcn Sheet, Dialog, Modal)
- Lazy-loaded controllers (`import()`)
- Dynamically inserted DOM (`insertAdjacentHTML`, Turbo Stream)
- Controllers that load data on connect

**Step 2: Add synchronous ready flag in initializing controller**

```javascript
// Controller that initializes async (drawer, modal, etc.)
export default class extends Controller {
  connect() {
    // Set flag immediately (synchronous)
    window.__myControllerReady = true;
    
    // Your existing initialization
    this.loadContent();
  }
}
```

**Step 3: Dispatch async ready event**

```javascript
export default class extends Controller {
  connect() {
    window.__myControllerReady = true;
    
    // Dispatch event for async listeners
    this.dispatch('ready');
  }
}
```

**Step 4: Wait for ready in dependent controller**

```javascript
// Controller that depends on async controller
export default class extends Controller {
  async triggerAction() {
    // Wait for ready using race pattern
    await Promise.race([
      // Immediate if flag set
      ...(window.__myControllerReady ? [Promise.resolve()] : []),
      // Wait for event
      new Promise(r => window.addEventListener('my-controller:ready', r, { once: true })),
      // Timeout fallback
      new Promise(r => setTimeout(r, 500))
    ]);
    
    // Now safe to proceed
    this.dispatchEvent('action');
  }
}
```

### Alternative: Registration Pattern

For multiple dependencies, use a registration system:

```javascript
// app/javascript/controllers/registry.js
class ControllerRegistry {
  constructor() {
    this.ready = new Set();
  }

  register(name) {
    this.ready.add(name);
    window.dispatchEvent(new CustomEvent(`controller:${name}:ready`));
  }

  async waitFor(name, timeout = 500) {
    if (this.ready.has(name)) return;
    
    await Promise.race([
      new Promise(r => window.addEventListener(`controller:${name}:ready`, r, { once: true })),
      new Promise(r => setTimeout(r, timeout))
    ]);
  }
}

export const registry = new ControllerRegistry();

// In controllers
import { registry } from './registry'

export default class extends Controller {
  connect() {
    registry.register('drawer');
  }
}

// Dependent controller
async open() {
  await registry.waitFor('drawer');
  this.dispatchEvent('drawer:open');
}
```

### Alternative Solution: Open Portal Component First (Simpler for Shadcn/Radix)

For portal-based UI libraries (Shadcn, Radix UI, Headless UI), an alternative approach is to **open the portal component BEFORE dispatching events**, eliminating the need for readiness flags.

**When to use this approach:**
- Portal component has an explicit open/show method (e.g., Shadcn Sheet's `open()`)
- You control the triggering interaction (button click, tile click)
- Multiple portal components may exist on same page (need specific targeting)
- Want simpler solution without global state (`window.__*Ready`)

**Pattern:**

```javascript
// Triggering Controller (e.g., button, tile)
export default class extends Controller {
  static values = {
    targetId: String
  }

  open(event) {
    event.preventDefault()
    
    // 1. Find the SPECIFIC portal component (by id)
    //    Required when multiple portal components exist on page
    const portalElement = document.querySelector(
      `#${this.targetIdValue}[data-controller~="shadcn--sheet"]`
    )
    
    if (!portalElement) {
      console.error(`Portal element ${this.targetIdValue} not found`)
      return
    }
    
    const portalController = this.application.getControllerForElementAndIdentifier(
      portalElement,
      "shadcn--sheet"
    )
    
    if (!portalController) {
      console.error('Portal controller not found')
      return
    }
    
    // 2. Open the portal (triggers <template> cloning + portal creation)
    portalController.open()
    
    // 3. Wait for portal DOM creation + nested controller connection
    requestAnimationFrame(() => {
      setTimeout(() => {
        // 4. NOW dispatch event to connected controller
        document.dispatchEvent(
          new CustomEvent("nested-controller:event", {
            detail: { data: "payload" }
          })
        )
      }, 50) // 50ms allows for portal + Stimulus connection
    })
  }
}
```

**Component Setup (Add ID for Targeting):**

```erb
<!-- app/components/drawer_component.html.erb -->
<%= render Shadcn::SheetComponent.new(
  id: "document-drawer",  # Enables specific targeting
  class: "drawer-styles"
) do |sheet| %>
  <div data-controller="nested-drawer">
    <!-- Drawer content -->
  </div>
<% end %>
```

**Nested Controller (Find Open Portal, Portal-Safe):**

```javascript
// Nested Controller (inside portal)
export default class extends Controller {
  connect() {
    console.log("[nested] connected")
    document.addEventListener("nested-controller:event", this.handleEvent.bind(this))
  }

  disconnect() {
    document.removeEventListener("nested-controller:event", this.handleEvent.bind(this))
  }

  findSheetController() {
    // Search for ANY open sheet (portal-safe approach)
    // Cannot use closest() because portal moves element to document.body
    const allSheets = document.querySelectorAll('[data-controller~="shadcn--sheet"]')
    for (const sheet of allSheets) {
      const controller = this.application.getControllerForElementAndIdentifier(
        sheet,
        "shadcn--sheet"
      )
      // Find the one that's actually open
      if (controller?.openValue) {
        return controller
      }
    }
    return null
  }

  handleEvent(event) {
    const { data } = event.detail
    console.log("[nested] received event:", data)
    // Handle event (load document, etc.)
  }
}
```

**Why This Works:**

1. **Portal opens first** → `<template>` content cloned to `document.body`
2. **requestAnimationFrame** → Ensures browser paints portal DOM
3. **setTimeout(50ms)** → Gives Stimulus time to scan new DOM and connect controllers
4. **Event dispatch** → Nested controller is NOW connected and listening

**Advantages over readiness flags:**
- ✅ No global state (`window.__*Ready`)
- ✅ No "ready" event boilerplate
- ✅ No fallback timeout checks (portal opens first, event after)
- ✅ Simpler code (3 steps: open, wait, dispatch)
- ✅ Handles multiple portals on page (ID targeting)
- ✅ No race condition (event always fires after controller connects)

**Disadvantages:**
- ⚠️ Requires portal component to have explicit open method
- ⚠️ ~50ms delay between click and event dispatch (imperceptible in practice)
- ⚠️ Requires component to have unique `id` for targeting
- ⚠️ Magic number (50ms) may need adjustment for slow systems

**When NOT to use:**
- Portal opens automatically (not triggered by user action)
- You don't control the portal open trigger
- Nested controller must initialize BEFORE portal opens
- Need zero-delay event dispatch (readiness flag approach better)

**Timing Breakdown:**

```javascript
// T=0ms: User clicks trigger
// T=0ms: portalController.open() called
// T=0-10ms: Portal DOM cloning starts
// T=10-20ms: Portal rendered in document.body
// T=20-30ms: Stimulus scans new DOM
// T=30-40ms: Nested controller connects
// T=50ms: Event dispatched (controller ready!)
```

**Testing:**

```ruby
test "clicking trigger opens portal and dispatches event" do
  visit page_with_portal_path
  
  # Click trigger
  find("[data-trigger-id='document-drawer']").click
  
  # Wait for portal creation (selector appears in portal container)
  assert_selector ".shadcn-sheet-portal", wait: 2
  
  # Verify nested controller connected
  assert_selector ".shadcn-sheet-portal [data-controller='nested-drawer']", wait: 1
  
  # Verify event was handled (e.g., content loaded)
  assert_text "Expected Content"
end
```

**Comparison with readiness flags:**

| Aspect | Readiness Flags | Open Portal First |
|--------|----------------|-------------------|
| Complexity | High (3 mechanisms) | Low (open, wait, dispatch) |
| Global state | Yes (`window.__*Ready`) | No |
| Works for any async | Yes | Only portal-triggered |
| Portal targeting | Not needed | Required (`id` attribute) |
| Delay | Up to 500ms | Fixed 50ms |
| Code lines | ~30 lines | ~15 lines |

**Real-world example:**

Document tile click opening canvas drawer:
- **Trigger:** Tile controller (`document-tile`)
- **Portal:** Shadcn Sheet with `id="canvas-document-drawer"`
- **Nested:** Canvas drawer controller (`canvas-drawer`)
- **Event:** `canvas-drawer:open` with document ID
- **Result:** 100% success rate, all 6 tests passing
- **Commit:** `f1257dc4` (Tala app, 2026-01-13)

**When to choose this approach:**

1. **Portal is user-triggered** (button click, tile click) → ✅ Use this
2. **Portal opens automatically** (page load, timer) → ❌ Use readiness flags
3. **Multiple portals on page** (drawer + modal + popover) → ✅ Use this (with IDs)
4. **Need minimum latency** (< 100ms) → ✅ Use this (50ms fixed)
5. **Complex async dependencies** (multiple controllers) → ❌ Use readiness flags

---

## Verification Checklist

- [ ] **First click works (not just second click)**
  - Reload page
  - Immediately click button
  - Feature should work without delay

- [ ] **All three sync paths tested**
  ```javascript
  // Test 1: Synchronous path (flag already set)
  window.__drawerReady = true;
  await open(); // Should return immediately
  
  // Test 2: Event path
  delete window.__drawerReady;
  setTimeout(() => window.dispatchEvent(new Event('drawer:ready')), 100);
  await open(); // Should wait for event
  
  // Test 3: Timeout path
  delete window.__drawerReady;
  // Don't dispatch event
  await open(); // Should timeout after 500ms
  ```

- [ ] **No console errors or warnings**

- [ ] **Works in slow network conditions**
  - Throttle CPU in DevTools (6x slowdown)
  - Test first interaction still works

- [ ] **Timeout value is appropriate**
  - 500ms is reasonable for most cases
  - Adjust if controller initialization is slower

## Tradeoffs

**Pros:**
- ✅ Eliminates race condition completely (all timing scenarios covered)
- ✅ Graceful degradation (timeout ensures feature works even if signals fail)
- ✅ Works with any async initialization (portals, lazy load, dynamic DOM)
- ✅ Minimal code complexity (one helper method)

**Cons:**
- ❌ Three synchronization mechanisms (conceptually complex)
- ❌ Global window scope pollution (`window.__*Ready` flags)
- ❌ 500ms timeout feels arbitrary (but necessary for fallback)
- ❌ Timeout adds latency in worst case (user waits up to 500ms)
- ❌ Doesn't work across browser contexts (iframes, popups)

**When to use this pattern:**
- Portal rendering causes async initialization (always)
- Event communication between controllers (common in Stimulus)
- First-click reliability is critical (UX requirement)
- 500ms timeout is acceptable latency

**When NOT to use:**
- Initialization is synchronous (no race condition)
- Controllers don't communicate via events (use outlets instead)
- Timeout latency is unacceptable (need different architecture)
- Cross-context communication needed (use postMessage)

## Related Patterns

- `pattern-ruby-rails-hotwire-portal-state-detection-stimulus` - Portal rendering breaks DOM assumptions
- `pattern-javascript-stimulus-outlets` - Alternative to events for controller communication

## References

- [Stimulus Controllers](https://stimulus.hotwired.dev/reference/controllers)
- [Stimulus Lifecycle Callbacks](https://stimulus.hotwired.dev/reference/lifecycle-callbacks)
- [MDN: Promise.race()](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/race)
- [MDN: CustomEvent](https://developer.mozilla.org/en-US/docs/Web/API/CustomEvent)

## Notes

**Why three mechanisms?**
- **Synchronous flag:** Handles case where controller already initialized (most common after first interaction)
- **Async event:** Handles case where controller initializing during wait (proper async pattern)
- **Timeout fallback:** Handles case where both fail (graceful degradation, prevents infinite hang)

**Performance impact:**
Minimal. `Promise.race()` is fast, and synchronous path returns immediately in common case (after first interaction).

**Testing implications:**
System tests may not catch this because test timing is different from real browser:
```ruby
# Tests pass but feature breaks in production
test "drawer opens on click" do
  click_button "Open Drawer"
  assert_selector "[data-state='open']" # Passes (test timing lucky)
end
```

Add explicit initialization verification:
```ruby
test "drawer opens on first click without wait" do
  visit page_path
  # Immediately click (no wait)
  click_button "Open Drawer"
  assert_selector "[data-state='open']", wait: 1
end
```

**Architecture smell:**
If you have many async controller dependencies, consider:
- Fewer controllers (consolidate responsibility)
- Outlets instead of events (Stimulus built-in communication)
- Server-driven state (let Turbo Streams handle updates)
