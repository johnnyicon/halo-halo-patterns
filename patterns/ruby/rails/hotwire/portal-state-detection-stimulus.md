---
id: "pattern-ruby-rails-hotwire-portal-state-detection-stimulus"
title: "Portal Component State Detection Fails in Stimulus Controllers"
type: troubleshooting
status: draft
confidence: high
revision: 1
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
dependencies:
  - name: shadcn-rails
    versions: ">=0.1"
  - name: radix-ui
    versions: ">=1.0"
domain: hotwire
tags:
  - stimulus
  - portals
  - react-portals
  - dom-scope
  - state-detection
introduced: 2026-01-12
last_verified: 2026-01-12
review_by: 2026-04-12
sanitized: true
related:
  - pattern-ruby-rails-hotwire-async-controller-initialization-race
---

# Portal Component State Detection Fails in Stimulus Controllers

## Context

When using React-based component libraries (Shadcn, Radix UI, Headless UI) in Rails applications with Stimulus, portal-rendered content breaks normal DOM hierarchy assumptions. Portals render content outside their parent container (typically at `document.body`), which causes Stimulus controllers to fail when checking state of portal children.

**This pattern applies when:**
- Using component libraries that render via React portals (Shadcn Sheet, Dialog, Modal, Popover)
- Stimulus controllers need to check if portal content is visible/open
- Controller queries its own element tree for portal state
- State detection returns false negatives (portal is open but controller thinks it's closed)

**Preconditions:**
- Rails 7+ with ViewComponent or similar component framework
- Stimulus 3+ for frontend interactivity
- Component library using React portals (Shadcn, Radix, Headless UI)
- Controller needs to query portal child state

## Symptoms

**Observable Behavior:**

1. **Portal opens but controller detects it as closed:**
```javascript
// Controller checks if sheet is open
const isOpen = this.sheetTarget.getAttribute('data-state') === 'open';
console.log('Is open:', isOpen); // false (but sheet is visibly open!)
```

2. **State-dependent logic doesn't trigger:**
- Conditional updates that should fire when portal is open don't execute
- Event handlers that check portal state before acting fail
- UI remains out of sync with actual visual state

3. **Browser console shows portal rendered elsewhere:**
```html
<!-- Controller's element tree -->
<div data-controller="my-controller">
  <div data-my-controller-target="sheet">
    <!-- Portal target is here, but content renders elsewhere -->
  </div>
</div>

<!-- Actual portal content (moved by React) -->
<body>
  <div data-state="open">
    <!-- Portal content rendered here, outside controller scope -->
  </div>
</body>
```

**Real-world symptom:**
Drawer/modal appears open on screen, but controller logic thinks it's closed, so dependent features (like updating drawer content when selection changes) don't fire.

## Root Cause

**Technical Explanation:**

React portals (used by Shadcn/Radix UI) move DOM nodes from their original location to a portal target (usually `document.body`). This breaks Stimulus's assumption that controller targets are children of the controller element.

**Why element-scoped queries fail:**

```javascript
// Controller element tree
<div data-controller="drawer">
  <div data-drawer-target="sheet"></div>  <!-- Original mount point -->
</div>

// After portal rendering
<div data-controller="drawer">
  <div data-drawer-target="sheet"></div>  <!-- Empty! Content moved -->
</div>

<body>
  <div data-state="open">  <!-- Actual content here -->
    <!-- Portal content -->
  </div>
</body>
```

**Query fails because:**
1. Controller queries `this.sheetTarget.getAttribute('data-state')`
2. `this.sheetTarget` points to original mount point (empty div)
3. Actual content with `data-state="open"` is in portal at `document.body`
4. Controller checks wrong element → always returns null or closed state

**Why this is subtle:**
- Portal rendering happens after controller connects
- Original element still exists (just empty)
- No JavaScript errors thrown (query succeeds but checks wrong element)
- Visual state (portal open) diverges from programmatic state (controller thinks closed)

## Fix

### Solution: Query Document Root Instead of Controller Element

**Before (WRONG - element-scoped query):**

```javascript
// app/javascript/controllers/drawer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sheet"]

  checkIfOpen() {
    // ❌ WRONG: Checks controller's element tree (portal content not here)
    const isOpen = this.sheetTarget.getAttribute('data-state') === 'open';
    
    if (isOpen) {
      this.updateContent(); // Never fires because isOpen is always false
    }
  }
}
```

**After (CORRECT - document-wide query):**

```javascript
// app/javascript/controllers/drawer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sheet"]

  checkIfOpen() {
    // ✅ CORRECT: Searches entire document for portal content
    const isOpen = !!document.querySelector('[data-state="open"]');
    
    if (isOpen) {
      this.updateContent(); // Now fires correctly
    }
  }
}
```

### Step-by-Step Implementation

**Step 1: Identify portal state queries in your controllers**

Search for patterns like:
```javascript
// Bad patterns
this.element.querySelector('[data-state]')
this.target.getAttribute('data-state')
this.element.contains(portalContent)
```

**Step 2: Replace with document-wide queries**

```javascript
// Before
const isOpen = this.sheetTarget.getAttribute('data-state') === 'open';

// After
const isOpen = !!document.querySelector('[data-state="open"]');
```

**Step 3: Add specificity if multiple portals exist**

```javascript
// If you have multiple portals, use more specific selectors
const isOpen = !!document.querySelector('[data-portal-id="drawer"][data-state="open"]');
```

**Step 4: Consider adding a helper method**

```javascript
// app/javascript/controllers/drawer_controller.js
export default class extends Controller {
  // Helper method for portal state detection
  isPortalOpen() {
    // Query document root, not controller element
    return !!document.querySelector('[data-state="open"]');
  }

  updateOnSelectionChange() {
    if (this.isPortalOpen()) {
      this.loadContent();
    }
  }
}
```

### Alternative: Use Custom Events Instead of State Queries

If state detection becomes complex, use custom events:

```javascript
// Portal component dispatches events
export default class extends Controller {
  connect() {
    this.element.addEventListener('portal:opened', this.handlePortalOpen.bind(this));
    this.element.addEventListener('portal:closed', this.handlePortalClose.bind(this));
  }

  handlePortalOpen() {
    this.isOpen = true;
    this.updateContent();
  }

  handlePortalClose() {
    this.isOpen = false;
  }
}
```

## Verification Checklist

- [ ] **State detection returns correct value**
  ```javascript
  // Open portal manually, then run in console:
  const isOpen = !!document.querySelector('[data-state="open"]');
  console.log('Portal open:', isOpen); // Should be true
  ```

- [ ] **Dependent logic triggers when portal opens**
  - Test features that should fire when portal is open
  - Verify updates/content loads occur correctly
  - Check event handlers respect portal state

- [ ] **Works with multiple portals**
  - Open multiple portals (if supported)
  - Verify queries target correct portal
  - Add specificity if needed

- [ ] **No false positives**
  - Close portal
  - Verify state detection returns false
  - Check logic doesn't fire when it shouldn't

- [ ] **Browser console shows no errors**
  ```javascript
  // Should return element or null (not throw error)
  document.querySelector('[data-state="open"]')
  ```

## Tradeoffs

**Pros:**
- ✅ Accurate state detection regardless of portal rendering
- ✅ Works with any portal-based component library
- ✅ Simple one-line fix
- ✅ No need to change component library or portal behavior

**Cons:**
- ❌ Document-wide query is less specific than element-scoped
- ❌ May conflict if multiple portals use same state attribute
- ❌ Breaks Stimulus convention of querying within controller element
- ❌ Harder to test in isolation (query depends on global DOM state)

**When to use this fix:**
- Portal content renders outside controller scope (always with React portals)
- State detection is critical for controller logic
- You can't modify portal rendering behavior
- Document-wide query is acceptable performance-wise

**When NOT to use:**
- Portal content stays within controller element (not a real portal)
- You can use custom events instead (cleaner architecture)
- Multiple portals create ambiguity (need event-based approach)
- State detection not needed (controller doesn't depend on portal state)

## Related Patterns

- `pattern-ruby-rails-hotwire-async-controller-initialization-race` - Portal rendering is async, so initialization race conditions common
- `pattern-ruby-rails-hotwire-turbo-stream-optimistic-ui-id-mismatch` - Similar DOM scope issues with optimistic UI

## References

- [React Portals Documentation](https://react.dev/reference/react-dom/createPortal)
- [Radix UI Portal](https://www.radix-ui.com/primitives/docs/utilities/portal)
- [Stimulus Controllers](https://stimulus.hotwired.dev/reference/controllers)

## Notes

**Why portals exist:**
Portals solve z-index and overflow clipping issues by rendering content at document root. This is necessary for modals, popovers, and dropdowns that must appear above all other content.

**Architectural smell:**
If you're doing lots of portal state detection, consider whether a modal/drawer component is the right pattern. Non-modal side panels often work better with non-portal collapsible components.

**Testing implications:**
System tests need to query portals correctly:
```ruby
# test/system/drawer_test.rb
# Query document root, not controller element
assert_selector "[data-state='open']", wait: 5
```
