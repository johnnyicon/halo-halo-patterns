---
id: "pattern-ruby-rails-stimulus-outlets"
title: "Stimulus Controller with Outlets Communication Pattern"
type: implementation
status: draft
confidence: high
revision: 1
languages:
  - javascript
  - ruby
frameworks:
  - stimulus
  - rails
dependencies:
  - stimulus
domain: stimulus
tags:
  - stimulus
  - outlets
  - component-communication
  - parent-child
  - events
  - coordination
introduced: 2026-01-13
last_verified: 2026-01-13
review_by: 2026-04-13
sanitized: true
related: []
---

# Stimulus Controller with Outlets Communication Pattern

## Summary
Architecture pattern for parent-child communication between Stimulus controllers using outlets, enabling clean separation of concerns and reusable component interactions.

## Context
Building complex UI interactions where multiple Stimulus controllers need to communicate, especially in scenarios with parent components that coordinate child behaviors or components that need to trigger actions in other components.

## Problem
- Direct controller coupling makes components hard to reuse
- Global event handling becomes unwieldy with multiple components
- Parent controllers need to coordinate multiple child controllers
- Components need to communicate without tight coupling

## Solution

### Outlet Definition Pattern
```javascript
// Parent controller that coordinates children
export default class extends Controller {
  static outlets = ["child-component", "another-child"]
  
  connect() {
    // Parent can access child controllers
    console.log("Child outlets:", this.childComponentOutlets)
  }
  
  coordinateAction() {
    // Trigger actions on all connected child outlets
    this.childComponentOutlets.forEach(child => {
      if (child.respondToParent) {
        child.respondToParent("some data")
      }
    })
  }
}
```

### Child Controller Pattern  
```javascript
// Child controller that can be controlled by parent
export default class extends Controller {
  static targets = ["element"]
  static values = { data: String }
  
  // Method that parent can call
  respondToParent(data) {
    this.dataValue = data
    this.updateDisplay()
  }
  
  // Child can also trigger parent actions
  notifyParent(eventData) {
    // Dispatch custom event that parent can listen for
    this.dispatch("childAction", { 
      detail: eventData,
      target: this.element 
    })
  }
  
  updateDisplay() {
    this.elementTarget.textContent = this.dataValue
  }
}
```

### HTML Template Pattern
```erb
<!-- Parent container with outlet declarations -->
<div data-controller="parent-coordinator"
     data-parent-coordinator-child-component-outlet="#child1 #child2"
     data-parent-coordinator-another-child-outlet="#another">
  
  <!-- Child controllers -->
  <div id="child1" 
       data-controller="child-component"
       data-child-component-data-value="initial"
       data-action="child-component:childAction->parent-coordinator#handleChildAction">
    <span data-child-component-target="element">Content</span>
  </div>
  
  <div id="child2" 
       data-controller="child-component"
       data-child-component-data-value="initial2">
    <span data-child-component-target="element">Content 2</span>
  </div>
  
  <div id="another"
       data-controller="another-child">
    <!-- Another child component -->
  </div>
</div>
```

### Real-World Example: Canvas Drawer with Document Tiles
```javascript
// apps/tala/app/frontend/controllers/canvas_drawer_controller.js
export default class extends Controller {
  static targets = ["sheet", "editor", "toolbar"]
  static values = { 
    documentId: String,
    isOpen: Boolean,
    isDirty: Boolean 
  }

  // Method that document tiles can call to open drawer
  open(documentId) {
    this.documentIdValue = documentId
    this.loadDocument()
    this.show()
  }

  async loadDocument() {
    // Load document and initialize editor
    const response = await fetch(`/ui/canvas_documents/${this.documentIdValue}`)
    const data = await response.json()
    this.setupEditor(data)
  }
}

// apps/tala/app/frontend/controllers/document_tile_controller.js  
export default class extends Controller {
  static outlets = ["canvas-drawer"]
  static values = { documentId: String }

  open() {
    // Communicate with canvas drawer outlet
    if (this.hasCanvasDrawerOutlet) {
      this.canvasDrawerOutlet.open(this.documentIdValue)
    }
  }
}
```

### ViewComponent Integration
```ruby
# app/components/ui/chat_messages/canvas_document_tile_component.rb
class Ui::ChatMessages::CanvasDocumentTileComponent < ViewComponent::Base
  def initialize(document:, drawer_controller: "canvas-drawer")
    @document = document
    @drawer_controller = drawer_controller
  end

  private

  attr_reader :document, :drawer_controller

  def outlet_selector
    "[data-controller='#{drawer_controller}']"
  end
end
```

```erb
<!-- app/components/ui/chat_messages/canvas_document_tile_component.html.erb -->
<article class="document-tile"
         data-controller="document-tile"
         data-document-tile-document-id-value="<%= document.id %>"
         data-document-tile-canvas-drawer-outlet="<%= outlet_selector %>"
         data-action="click->document-tile#open">
  
  <h3><%= document.title %></h3>
  <p><%= document.preview_text %></p>
</article>
```

## Benefits
- **Loose Coupling**: Controllers communicate without direct references
- **Reusability**: Child controllers can work with different parents
- **Composability**: Easy to build complex UIs from smaller components  
- **Type Safety**: TypeScript-friendly with proper outlet declarations
- **Testability**: Easy to test controllers in isolation

## When to Use
- ✅ Complex UI interactions with multiple coordinated components
- ✅ Parent-child controller relationships
- ✅ Reusable components that need to work in different contexts
- ✅ Modal/drawer patterns that can be triggered from multiple sources

## When NOT to Use
- ❌ Simple, self-contained components
- ❌ Components that never need to communicate
- ❌ Global state that should use a state management library

## Trade-offs
**Pros:**
- Clean separation of concerns
- Highly reusable components
- Easy to reason about component relationships
- Good TypeScript support

**Cons:**
- More complex than direct method calls
- Requires understanding of Stimulus outlets concept
- Can be overkill for simple interactions
- Debugging communication can be harder

## Implementation Tips

### 1. Outlet Naming Convention
```javascript
// Use consistent naming for outlets
static outlets = [
  "canvas-drawer",     // kebab-case matches controller names
  "version-history", 
  "conflict-dialog"
]
```

### 2. Graceful Outlet Handling
```javascript
openDrawer(data) {
  // Always check if outlet exists
  if (this.hasCanvasDrawerOutlet) {
    this.canvasDrawerOutlet.open(data)
  } else {
    // Fallback behavior or warning
    console.warn("Canvas drawer outlet not found")
  }
}
```

### 3. Event-Based Fallback
```javascript
// Child can use events if outlets aren't available
notifyParent(data) {
  if (this.hasParentOutlet) {
    this.parentOutlet.handleChildUpdate(data)
  } else {
    // Fall back to custom events
    this.dispatch("childUpdate", { detail: data })
  }
}
```

### 4. Outlet Discovery
```erb
<!-- Dynamic outlet discovery for flexible layouts -->
<div data-controller="document-tile"
     data-document-tile-canvas-drawer-outlet="[data-controller='canvas-drawer']">
```

## Related Patterns
- Observer Pattern  
- Mediator Pattern
- Component Communication (React/Vue)
- Publish-Subscribe Pattern

## Debugging Tips
- Use browser dev tools to inspect `data-*-outlet` attributes
- Check `this.hasXxxxOutlet` before calling outlet methods
- Add logging to outlet connection/disconnection events
- Verify outlet selectors match actual controller elements

## Tags
`stimulus` `javascript` `component-communication` `outlets` `frontend-architecture`

---
**Pattern ID**: stimulus-controller-outlets-pattern  
**Created**: 2026-01-13  
**Language**: JavaScript/Stimulus  
**Complexity**: Medium-High  
**Maturity**: Stable