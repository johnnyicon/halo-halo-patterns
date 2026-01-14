---
id: "pattern-ruby-rails-views-duplicate-template-feature-inconsistency"
title: "Feature Works in One View But Not Another Due to Duplicate Templates"
type: troubleshooting
status: validated
confidence: high
revision: 1
languages:
  - language: ruby
    versions: ">=3.0"
  - language: html
    versions: "erb"
frameworks:
  - name: rails
    versions: ">=7.0 <9.0"
  - name: hotwire
    versions: ">=1.0"
dependencies: []
domain: views
tags:
  - views
  - partials
  - DRY
  - turbo-streams
  - consistency
  - templates
introduced: 2026-01-13
last_verified: 2026-01-13
review_by: 2026-04-13
sanitized: true
related:
  - pattern-ruby-rails-hotwire-turbo-stream-optimistic-ui-id-mismatch
---

# Feature Works in One View But Not Another Due to Duplicate Templates

## Context

In Rails applications with multiple views rendering the same entity (e.g., standalone view + embedded view, or multiple contexts showing the same model), it's common to duplicate rendering logic across templates. When you add a new feature (like a tile, button, or status indicator) to one template, you must manually add it to all other templates.

**This pattern applies when:**
- Multiple ERB templates render the same entity with duplicated markup
- New feature added to one template but not others
- "Works in view X but not view Y" bugs appear
- Turbo Stream broadcasts may render differently than page loads
- Team doesn't realize multiple templates exist for same entity

**Preconditions:**
- Two or more templates rendering the same model/entity
- Logic for rendering entity duplicated across templates
- No shared partial or component for entity rendering

## Symptoms

**Observable Behavior:**

1. **Feature appears in one view but not another:**
```erb
<!-- Standalone view (show.html.erb) -->
<div class="message">
  <%= message.content %>
  <%= render FeatureTileComponent.new(entity: message) if message.has_feature? %> <!-- ✅ PRESENT -->
</div>

<!-- Context-scoped view (_thread_view.html.erb) -->
<div class="message">
  <%= message.content %>
  <!-- ❌ MISSING - tile logic not duplicated here -->
</div>
```

2. **Works during page load but not after Turbo Stream update:**
```ruby
# Page template includes feature
<div class="message">...</div>

# Turbo Stream broadcast uses different partial/inline rendering
broadcast_append_to "messages", target: "messages-list", partial: "message_simple"
# ❌ 'message_simple' doesn't have the feature
```

3. **Tests pass in one context but fail in another:**
```ruby
test "tile appears in standalone view" do
  visit entity_path(@entity)
  assert_selector "[data-feature-tile]" # ✅ PASS
end

test "tile appears in context-scoped view" do
  visit context_entity_path(@context, @entity)
  assert_selector "[data-feature-tile]" # ❌ FAIL
end
```

**Real-world symptoms:**
- User reports: "I see the feature in the main page, but when I view from [context], it's missing"
- QA finds: "Feature works in desktop view but not mobile template"
- Developer discovers: "New button appears in list view but not grid view"

## Root Cause

**Technical Explanation:**

Rails templates are **files**, not functions. There's no automatic inheritance or composition. When you have:

```
app/views/entities/show.html.erb           # Renders entities
app/views/contexts/entities/_thread.html.erb  # Also renders entities
```

Each template is **independent**. Adding markup to one doesn't affect the other.

**Why this happens:**

1. **Initial implementation:** Developer creates first view, writes entity rendering inline
2. **Second view added:** Developer copies markup to new template (DRY violation)
3. **Feature added:** Developer adds to first template, doesn't realize second template exists
4. **Bug reported:** "Works in X but not Y"

**Why it's hard to catch:**

- Tests often only test one view context
- Developers focus on the view they're working in
- No warning/error when templates diverge
- Code review may not catch missing feature in second template

**Turbo Stream complication:**

If you use Turbo Streams for live updates, you have **three** places to update:
1. Template A (standalone view)
2. Template B (embedded view)
3. Broadcast partial (Turbo Stream rendering)

Forgetting any one causes inconsistency.

## Fix

### Solution: Extract to Shared Partial (Single Source of Truth)

**Step 1: Create shared partial**

```erb
<%# app/views/entities/_entity_bubble.html.erb
    
    Shared rendering for entities across all contexts.
    Used in: show.html.erb, _thread_view.html.erb, Turbo broadcasts
    
    Required locals:
      entity - Entity instance
    
    Optional locals:
      show_context_indicator - Boolean (default: true)
    
    Architecture Note:
      This partial is the SINGLE SOURCE OF TRUTH for entity rendering.
      All display features go here. Do NOT duplicate this logic.
%>

<% show_context_indicator = local_assigns.fetch(:show_context_indicator, true) %>

<div id="entity-<%= entity.id %>" class="entity-bubble">
  <%= entity.content %>
  
  <%# ALL FEATURES GO HERE - Added once, appear everywhere %>
  <%= render FeatureTileComponent.new(entity: entity) if entity.has_feature? %>
  <%= render ActionButtonsComponent.new(entity: entity) %>
  <%= render StatusIndicatorComponent.new(entity: entity) if show_context_indicator %>
</div>
```

**Step 2: Refactor all templates to use partial**

```erb
<!-- app/views/entities/show.html.erb -->
<div id="entities">
  <% @entities.each do |entity| %>
    <%= render "entities/entity_bubble", entity: entity %>
  <% end %>
</div>

<!-- app/views/contexts/entities/_thread_view.html.erb -->
<div id="thread-entities">
  <% entities.each do |entity| %>
    <%= render "entities/entity_bubble", entity: entity %>
  <% end %>
</div>
```

**Step 3: Update Turbo Stream broadcasts**

```ruby
# app/models/entity.rb
after_create_commit do
  broadcast_append_to(
    "entities-#{context_id}",
    target: "entities",
    partial: "entities/entity_bubble", # ✅ Same partial as views
    locals: { entity: self }
  )
end
```

**Result:** Three places now render identically because they all use the same partial.

### Alternative: ViewComponent (For Complex Rendering)

When entity rendering has complex logic, helpers, or state management:

```ruby
# app/components/entity_component.rb
class EntityComponent < ViewComponent::Base
  def initialize(entity:, show_context_indicator: true)
    @entity = entity
    @show_context_indicator = show_context_indicator
  end

  # Can add instance methods for computed properties
  def should_show_feature_tile?
    @entity.has_feature? && @entity.feature.published?
  end

  def status_class
    @entity.active? ? "status-active" : "status-inactive"
  end
end
```

**When to use ViewComponent vs Partial:**

| Criteria | Shared Partial | ViewComponent |
|----------|---------------|---------------|
| Complexity | Simple markup + basic conditionals | Complex logic, helpers, state |
| Effort | Minimal (extract + replace) | Medium (component class + template) |
| Testing | System tests | Unit tests + system tests |
| Encapsulation | Low (no instance methods) | High (full Ruby class) |
| Team familiarity | Standard Rails pattern | Requires ViewComponent knowledge |

## Verification Checklist

After extracting to shared partial:

- [ ] **All templates render partial** (no inline entity rendering remains)
- [ ] **Turbo broadcasts use partial** (check `broadcast_*` calls in models)
- [ ] **Tests pass in all view contexts** (standalone, embedded, broadcasts)
- [ ] **New features only need one change** (add to partial, appears everywhere)
- [ ] **Partial header documents usage** (which views use it, required locals)
- [ ] **No markup duplication** (grep for duplicate patterns in views)

**Test coverage for all contexts:**

```ruby
test "feature appears in standalone view" do
  visit entity_path(@entity)
  assert_selector "[data-feature-tile]"
end

test "feature appears in embedded view" do
  visit context_entity_path(@context, @entity)
  assert_selector "[data-feature-tile]"
end

test "feature appears after Turbo Stream broadcast" do
  visit entity_path(@entity)
  # Trigger action that broadcasts new entity
  perform_action_that_creates_entity
  assert_selector "[data-feature-tile]" # Feature present in broadcast
end
```

**Code review checklist:**

- [ ] Search codebase for entity rendering patterns
- [ ] Verify no other templates render entity inline
- [ ] Check Turbo broadcasts use correct partial
- [ ] Confirm tests cover all view contexts

## Tradeoffs

### Shared Partial Approach

**Pros:**
- ✅ Single source of truth (add feature once, appears everywhere)
- ✅ Minimal refactoring (extract + replace)
- ✅ Works seamlessly with Turbo Streams
- ✅ No new dependencies (standard Rails pattern)
- ✅ Easy to test (test one partial, not N templates)
- ✅ Clear documentation in partial header

**Cons:**
- ⚠️ ERB partials lack encapsulation (no instance methods)
- ⚠️ Must pass locals explicitly (can't access instance variables)
- ⚠️ Harder to unit test in isolation (need Rails environment)
- ⚠️ May become "God partial" if too many features added

### ViewComponent Alternative

**Pros:**
- ✅ Full Ruby class with instance methods
- ✅ Can unit test without Rails environment
- ✅ Better encapsulation and state management
- ✅ Preview system for development
- ✅ More modular and reusable

**Cons:**
- ⚠️ More refactoring effort (component class + template)
- ⚠️ Team learning curve for ViewComponent
- ⚠️ Additional dependency (view_component gem)
- ⚠️ May be over-engineering for simple rendering

### Decision Criteria

**Use Shared Partial when:**
- Rendering is mostly markup + simple conditionals
- No complex helper methods needed
- Want minimal refactoring for MVP
- Team prefers standard Rails patterns
- Entity rendering is straightforward

**Use ViewComponent when:**
- Rendering logic has many conditionals/helpers
- Need instance methods for computed properties
- Want preview system for development
- Team comfortable with component architecture
- Planning to reuse component across multiple apps

## Related Patterns

- **Turbo Stream broadcast inconsistencies** - Often caused by broadcast using different partial than views
- **ViewComponent vs partial decision** - When to extract to component vs shared partial
- **Single Responsibility in views** - Keeping view logic focused and DRY

## References

**Real-world incidents:**
- Canvas document tiles missing in context-scoped chat (Tala app, 2026-01-13)
  - Commit: `1de9bd71` - "fix(chat): extract message bubble to shared partial for DRY architecture"
  - Files: Created `_message_bubble.html.erb`, refactored `show.html.erb` and `_thread_view.html.erb`
  - Result: Feature appears in both views + Turbo broadcasts

**Detection commands:**

```bash
# Find potential duplicate entity rendering
grep -r "render.*entity" app/views/ | sort | uniq -c | sort -nr

# Find views that might need refactoring
find app/views -name "*.html.erb" -exec grep -l "class=\"entity-" {} \;

# Check Turbo broadcasts
grep -r "broadcast_.*_to" app/models/
```

**Migration checklist:**

```markdown
## Extracting to Shared Partial

- [ ] Identify all templates rendering entity
- [ ] Create shared partial with documentation header
- [ ] Extract entity rendering to partial
- [ ] Refactor template A to use partial
- [ ] Refactor template B to use partial
- [ ] Update Turbo broadcasts to use partial
- [ ] Add tests for all view contexts
- [ ] Verify feature appears in all contexts
- [ ] Remove inline entity rendering from templates
- [ ] Code review for any missed templates
```

**Performance considerations:**

Shared partials have negligible performance impact:
- Rails caches partial lookups
- Rendering overhead is minimal (~0.1ms per render)
- Much faster than debugging "works in X not Y" bugs
- Easier to optimize one partial than N templates
