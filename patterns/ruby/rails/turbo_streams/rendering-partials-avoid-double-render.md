---
id: "pattern-ruby-rails-turbo-streams-rendering-partials"
title: "Turbo Streams: Use Partials to Avoid DoubleRenderError"
type: troubleshooting
status: draft
confidence: high
revision: 1
languages:
  - language: ruby
    versions: ">=3.0"
frameworks:
  - name: rails
    versions: ">=7.0"
  - name: turbo-rails
    versions: ">=1.0"
dependencies:
  - name: view_component
    versions: ">=2.0"
    optional: true
domain: turbo_streams
tags:
  - turbo-streams
  - rendering
  - double-render-error
  - partials
  - view-component
  - hotwire
introduced: 2026-01-26
last_verified: 2026-01-26
review_by: 2026-04-26
sanitized: true
related: []
---

# Turbo Streams: Use Partials to Avoid DoubleRenderError

## Context

When dynamically adding items to a list via Turbo Streams, developers often try to render ViewComponents or partials directly inside Turbo Stream blocks, which causes `AbstractController::DoubleRenderError`.

**Common scenario:**
- User creates a new resource (folder, document, comment, etc.)
- Controller responds with Turbo Stream to add item to existing list
- Item needs to match existing rendering structure (classes, data attributes, etc.)

**Why this pattern exists:**
- Rails prohibits calling `render()` inside block-based helpers like `helpers.tag.div`
- Developers don't check existing rendering structure before implementing Turbo Stream updates
- Component names are assumed without verification

## Symptoms

1. **Page reload instead of Turbo Stream update**
   - JavaScript removing Turbo behavior (e.g., `window.location.reload()`)
   - Turbo Stream response not being handled

2. **`AbstractController::DoubleRenderError`**
   ```
   AbstractController::DoubleRenderError: Render and/or redirect were called 
   multiple times in this action. Please note that you may only call render 
   OR redirect, and at most once per action.
   ```

3. **Attempted to render inside `helpers.tag` block**
   ```ruby
   turbo_stream.prepend("list-id") do
     helpers.tag.div do
       render SomeComponent.new(...)  # ❌ CAUSES ERROR
     end
   end
   ```

4. **Component class name errors**
   - `NameError: uninitialized constant Components::WrongName`
   - Used assumed component name without checking source

## Root Cause

**Rails rendering constraint:** Cannot call `render()` inside block-based helper methods like `helpers.tag.div`, `helpers.tag.li`, etc.

**Why developers hit this:**
1. Don't search for existing item rendering patterns before implementing Turbo Stream
2. Try to use ViewComponent or `render()` directly inside Turbo Stream block
3. Make incremental changes without understanding full rendering flow
4. Assume component names without verification

**Discovery gap:**
- Skip semantic search for existing list item rendering
- Don't grep for existing partial usage
- Assume structure matches mental model without checking DOM

## Fix

### Step 1: Check Existing Rendering Structure FIRST

**Before implementing Turbo Stream, find where items are currently rendered:**

```bash
# Find existing list rendering
grep -r "render.*Component" app/views/controller_name/
# Or search for partial usage  
grep -r "partial:" app/views/controller_name/
```

**Read the actual view file:**

```ruby
# Example: app/views/items/index.html.erb
<div id="items-list">
  <% @items.each do |item| %>
    <div class="item-wrapper">
      <div class="list-view-item">
        <%= render Items::ListItemComponent.new(item: item) %>
      </div>
      <div class="grid-view-item">
        <%= render Items::GridItemComponent.new(item: item) %>
      </div>
    </div>
  <% end %>
</div>
```

**Verify:**
- What partial/component renders each item?
- What locals does it expect?
- What wrapper structure exists (div classes, data attributes)?
- Are there multiple views (list vs grid)?

### Step 2: Create Partial Matching Existing Structure

**Extract rendering logic to a reusable partial:**

```erb
<!-- app/views/items/_list_item.html.erb -->
<div class="item-wrapper">
  <%# List view %>
  <div class="list-view-item">
    <%= render Items::ListItemComponent.new(item: item) %>
  </div>
  
  <%# Grid view %>
  <div class="grid-view-item">
    <%= render Items::GridItemComponent.new(item: item) %>
  </div>
</div>
```

**Key points:**
- Match exact wrapper structure from existing view
- Include all CSS classes and data attributes
- Support both list and grid views if applicable
- Pass `item` hash with all required fields

### Step 3: Use Partial in Turbo Stream Response

**In controller (create action):**

```ruby
def create
  @item = current_organization.items.create!(item_params)

  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: [
        # Prepend to main list
        turbo_stream.prepend(
          "items-list",
          partial: "items/list_item",
          locals: { 
            item: {
              id: @item.id,
              title: @item.title,
              updated_at: @item.updated_at,
              # ... other fields
            }
          }
        ),
        # Optionally update sidebar/tree
        turbo_stream.append(
          "items-tree-root",
          partial: "items/tree_item_wrapper",
          locals: { item: @item }
        ),
        # Success toast
        turbo_stream.append("flash-container") do
          render partial: "shared/flash_message", 
                 locals: { message: "Item created successfully" }
        end
      ].compact
    end
    format.html { redirect_to items_path }
  end
end
```

**Key points:**
- Use `turbo_stream.prepend/append(target_id, partial: "path", locals: {...})`
- Pass item data as hash (not ActiveRecord object if serialization needed)
- Return array of Turbo Streams for multiple updates
- Use `.compact` to filter out conditional streams

### Step 4: Add Target IDs to DOM

**Ensure target elements have IDs for Turbo Stream targeting:**

```erb
<!-- In main view: app/views/items/index.html.erb -->
<div id="items-list" data-controller="items--list">
  <%= render partial: "items/list_item", collection: @items, as: :item %>
</div>

<!-- In sidebar: app/views/layouts/_sidebar.html.erb -->
<div id="items-tree-root" data-controller="items--tree">
  <%= render ItemsTreeComponent.new(items: @root_items) %>
</div>
```

### Step 5: Remove Page Reload from JavaScript

**If you previously had page reload workarounds, remove them:**

```javascript
// app/frontend/controllers/item_create_controller.js

// ❌ BEFORE (anti-pattern)
afterCreate(event) {
  if (!event.detail?.success) return
  const portal = this.element.closest('.dialog-portal')
  if (portal) portal.remove()
  setTimeout(() => window.location.reload(), 100)  // ❌ REMOVE THIS
}

// ✅ AFTER
afterCreate(event) {
  if (!event.detail?.success) return
  const portal = this.element.closest('.dialog-portal')
  if (portal) portal.remove()
  // Turbo Streams from server handle DOM updates
}
```

## Verification Checklist

- [ ] Checked existing rendering structure (viewed actual template file)
- [ ] Created partial that matches existing structure exactly
- [ ] Verified component class names exist (no typos)
- [ ] Used `turbo_stream.prepend/append(target, partial: "path", locals: {...})`
- [ ] Added target IDs to DOM elements
- [ ] Removed page reload workarounds from JavaScript
- [ ] Tested create action (no page reload)
- [ ] New item appears in correct location with correct styling
- [ ] No DoubleRenderError in logs
- [ ] Item has all interactive behaviors (Stimulus controllers work)
- [ ] Works in both list and grid views (if applicable)

## Anti-Pattern Examples

### ❌ Wrong: Render Inside Block

```ruby
# Causes AbstractController::DoubleRenderError
turbo_stream.prepend("items-list") do
  helpers.tag.div(class: "item-card") do
    render Items::CardComponent.new(item: @item)
  end
end
```

### ❌ Wrong: Guessing Component Names

```ruby
# Assumed "Items::CardComponent" exists
# Actually named "Items::GridItemComponent"
turbo_stream.prepend("items-list", 
  partial: "items/card",  # Wrong partial name
  locals: { item: @item }
)
# Result: ActionView::MissingTemplate
```

### ❌ Wrong: Inline HTML String

```ruby
# Hard to maintain, duplicates structure, brittle
turbo_stream.prepend("items-list") do
  helpers.tag.div(class: "item-wrapper") do
    helpers.tag.div(class: "item-title") do
      @item.title
    end
    # ... more inline HTML ...
  end
end
```

### ✅ Right: Use Partial

```ruby
# Created _list_item.html.erb partial matching existing structure
turbo_stream.prepend("items-list",
  partial: "items/list_item",
  locals: { item: @item }
)
```

## Tradeoffs

### ✅ Partial Approach (Recommended)

**Pros:**
- Works with both ViewComponents and ERB
- Avoids DoubleRenderError
- Reusable in both initial render and Turbo Streams
- Clear separation of concerns
- Easy to test and maintain
- Matches existing structure exactly

**Cons:**
- Requires creating separate partial file
- Slightly more indirection

### ❌ Direct Render in Block (Doesn't Work)

**Attempted pattern:**
```ruby
turbo_stream.prepend("list") do
  helpers.tag.div { render Component.new(...) }
end
```

**Why it fails:**
- Rails prohibits nested render() calls in helper blocks
- Results in DoubleRenderError
- Cannot be used

### ❌ Inline HTML String (Brittle)

**Attempted pattern:**
```ruby
turbo_stream.prepend("list") do
  helpers.tag.div(class: "item") do
    # ... inline HTML construction ...
  end
end
```

**Why to avoid:**
- Duplicates rendering logic
- Hard to maintain (structure changes require updates in multiple places)
- No component reuse
- Error-prone (easy to miss classes or data attributes)

## Pattern Summary

**When adding items to lists via Turbo Streams:**

1. ✅ **Check existing rendering structure FIRST**
   - Read actual view file
   - Note wrapper structure, classes, data attributes
   - Verify component names

2. ✅ **Create partial matching that structure**
   - Extract to reusable partial
   - Include all views (list/grid if applicable)
   - Match exact wrapper structure

3. ✅ **Use `turbo_stream.method(target, partial: "path", locals: {...})`**
   - Pass data as hash in locals
   - Return array for multiple streams
   - Use `.compact` for conditional streams

4. ✅ **NEVER call render() inside helpers.tag blocks**
   - Results in DoubleRenderError
   - Use partials instead

5. ✅ **Verify component class names exist before using**
   - Check actual file/class name
   - Don't assume based on similar components

**Time saved:** 5 minutes of discovery prevents 30+ minutes of debugging DoubleRenderError loops.

## References

- [Rails Guides: Turbo Streams](https://guides.rubyonrails.org/working_with_javascript_in_rails.html#turbo-streams)
- [Turbo Handbook: Streams](https://turbo.hotwired.dev/handbook/streams)
- [ViewComponent Documentation](https://viewcomponent.org/)
