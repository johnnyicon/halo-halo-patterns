---
id: "pattern-ruby-rails-viewcomponent-stimulus"
title: "ViewComponent + Stimulus Integration Pattern"
type: implementation
status: draft
confidence: high
revision: 1
languages:
  - ruby
  - javascript
frameworks:
  - rails
  - stimulus
  - view_component
dependencies:
  - view_component
  - stimulus
domain: view_components
tags:
  - viewcomponent
  - stimulus
  - integration
  - data-attributes
  - server-rendering
  - component-architecture
introduced: 2026-01-13
last_verified: 2026-01-13
review_by: 2026-04-13
sanitized: true
related:
  - pattern-ruby-rails-stimulus-outlets
---

# ViewComponent + Stimulus Integration Pattern

## Summary
Seamless integration pattern between Rails ViewComponents and Stimulus controllers, using data attributes for clean separation and component reusability.

## Context
Building Rails applications with ViewComponents for server-side rendering and Stimulus for client-side interactions, where you need components to be both reusable and interactive.

## Problem
- ViewComponents and Stimulus controllers exist in separate layers
- Data needs to flow from Ruby to JavaScript without tight coupling  
- Components should be reusable with different JavaScript behaviors
- Server-rendered HTML needs to trigger client-side behaviors

## Solution

### ViewComponent with Data Attributes
```ruby
# app/components/ui/canvas_documents/drawer_component.rb
class Ui::CanvasDocuments::DrawerComponent < ViewComponent::Base
  def initialize(document: nil, is_open: false)
    @document = document
    @is_open = is_open
  end

  private

  attr_reader :document, :is_open

  # Helper methods for generating data attributes
  def drawer_data_attributes
    {
      controller: "canvas-drawer",
      "canvas-drawer-document-id-value": document&.id,
      "canvas-drawer-is-open-value": is_open,
      "canvas-drawer-is-dirty-value": false
    }
  end

  def editor_data_attributes
    {
      "canvas-drawer-target": "editor",
      "canvas-drawer-action": "input->canvas-drawer#markDirty"
    }
  end
end
```

### ViewComponent Template
```erb
<!-- app/components/ui/canvas_documents/drawer_component.html.erb -->
<%= render Shadcn::SheetComponent.new(
      open: is_open,
      data: drawer_data_attributes
    ) do |sheet| %>

  <%= sheet.with_content(class: "flex flex-col h-full", data: { "canvas-drawer-target" => "sheet" }) do %>
    
    <!-- Header with data attributes for targets -->
    <%= sheet.with_header(class: "border-b", data: { "canvas-drawer-target" => "header" }) do %>
      <div class="flex items-center justify-between">
        <h2 data-canvas-drawer-target="title">
          <%= document&.title || "New Document" %>
        </h2>
        
        <!-- Save button with action -->
        <button type="button"
                class="btn btn-primary"
                data-action="click->canvas-drawer#save"
                data-canvas-drawer-target="saveButton">
          <span data-canvas-drawer-target="saveStatus">Save</span>
        </button>
      </div>
    <% end %>

    <!-- Editor with rich data attributes -->
    <div class="flex-1 p-4">
      <div data-canvas-drawer-target="editor"
           data-action="<%= editor_data_attributes[:'canvas-drawer-action'] %>"
           class="prose max-w-none min-h-full">
        <%= document&.body_markdown || "" %>
      </div>
    </div>

    <!-- Footer with version info -->
    <%= sheet.with_footer do %>
      <div class="flex items-center justify-between">
        <span class="text-sm text-muted-foreground"
              data-canvas-drawer-target="versionInfo">
          <% if document&.current_version %>
            Version <%= document.current_version.version_number %>
          <% end %>
        </span>
        
        <!-- Version dropdown trigger -->
        <button type="button"
                data-action="click->canvas-drawer#showVersionHistory"
                data-canvas-drawer-target="versionButton">
          History
        </button>
      </div>
    <% end %>

  <% end %>
<% end %>
```

### Corresponding Stimulus Controller
```javascript
// app/frontend/controllers/canvas_drawer_controller.js
export default class extends Controller {
  static targets = [
    "sheet", 
    "editor", 
    "title", 
    "saveButton", 
    "saveStatus",
    "versionInfo",
    "versionButton"
  ]
  
  static values = {
    documentId: String,
    isOpen: Boolean,
    isDirty: Boolean
  }

  connect() {
    console.log("[canvas-drawer] connect", this.documentIdValue)
    this.setupEditor()
    this.updateSaveStatus()
  }

  // Value change callbacks automatically called by Stimulus
  documentIdValueChanged() {
    if (this.documentIdValue) {
      this.loadDocument()
    }
  }

  isDirtyValueChanged() {
    this.updateSaveStatus()
  }

  // Target callbacks
  saveButtonTargetConnected() {
    this.updateSaveStatus()
  }

  // Actions called from data-action attributes
  markDirty() {
    this.isDirtyValue = true
  }

  async save() {
    // Implementation...
    this.saveStatusTarget.textContent = "Saving..."
    // ... save logic
    this.isDirtyValue = false
  }

  showVersionHistory() {
    // Version history logic using versionButtonTarget
  }

  // Private methods
  updateSaveStatus() {
    if (!this.hasSaveStatusTarget) return
    
    this.saveStatusTarget.textContent = this.isDirtyValue ? "Save" : "Saved"
    this.saveButtonTarget.disabled = !this.isDirtyValue
  }
}
```

### Parent Template Integration
```erb
<!-- app/views/ui/chat/show.html.erb -->
<div class="flex h-screen">
  <!-- Chat content -->
  <main class="flex-1">
    <!-- Chat messages with document tiles -->
    <% @messages.each do |message| %>
      <% if message.canvas_document %>
        <%= render Ui::ChatMessages::CanvasDocumentTileComponent.new(
              document: message.canvas_document,
              drawer_controller: "canvas-drawer"
            ) %>
      <% end %>
    <% end %>
  </main>

  <!-- Drawer component -->
  <%= render Ui::CanvasDocuments::DrawerComponent.new(
        document: @current_document,
        is_open: params[:drawer_open]
      ) %>
</div>
```

### Data Flow Patterns

#### 1. Ruby → JavaScript (Initial State)
```ruby
def drawer_data_attributes
  {
    controller: "canvas-drawer",
    "canvas-drawer-document-id-value": document&.id,
    "canvas-drawer-content-value": document&.body_markdown&.to_json,
    "canvas-drawer-metadata-value": document&.metadata&.to_json
  }
end
```

#### 2. JavaScript → Ruby (Form Submissions)
```javascript
async save() {
  const formData = new FormData()
  formData.append('title', this.titleTarget.value)
  formData.append('body_markdown', this.editor.getMarkdown())
  
  const response = await fetch(`/ui/canvas_documents/${this.documentIdValue}`, {
    method: 'PATCH',
    body: formData,
    headers: { 'X-CSRF-Token': this.csrfToken }
  })
  
  if (response.ok) {
    this.isDirtyValue = false
  }
}
```

#### 3. Component Communication
```ruby
# Document tile component connects to drawer
def tile_data_attributes
  {
    controller: "document-tile",
    "document-tile-document-id-value": document.id,
    "document-tile-canvas-drawer-outlet": "[data-controller='canvas-drawer']",
    action: "click->document-tile#open"
  }
end
```

## Benefits
- **Clean Separation**: Ruby handles rendering, JavaScript handles interactions
- **Reusability**: Components work in different contexts with different data
- **Type Safety**: Stimulus values provide runtime type checking
- **Server-Side Rendering**: Full HTML delivered, enhanced with JavaScript
- **Progressive Enhancement**: Works without JavaScript, enhanced with it

## When to Use
- ✅ Interactive components that need server-rendered HTML
- ✅ Reusable UI components across different pages
- ✅ Rich client interactions with Rails backend
- ✅ Forms and editors with complex state management

## When NOT to Use  
- ❌ Purely static components with no interactions
- ❌ Simple JavaScript behaviors that don't need data passing
- ❌ Components that would be better as pure client-side components

## Trade-offs
**Pros:**
- Leverages Rails strengths (server rendering, conventions)
- Clean data flow from server to client
- Easy testing of both Ruby and JavaScript layers
- Good performance with server-side rendering

**Cons:**
- More complex than pure client-side components
- Requires understanding both ViewComponent and Stimulus
- Data serialization overhead for complex objects
- Limited to Stimulus patterns for client interactions

## Implementation Tips

### 1. Data Attribute Helpers
```ruby
private

def stimulus_data(controller, **attributes)
  base = { controller: controller }
  
  attributes.each do |key, value|
    case value
    when Hash, Array
      base["#{controller}-#{key}-value"] = value.to_json
    else
      base["#{controller}-#{key}-value"] = value
    end
  end
  
  base
end
```

### 2. Value Validation
```javascript
static values = {
  documentId: { type: String, default: "" },
  isOpen: { type: Boolean, default: false },
  metadata: { type: Object, default: {} }
}

connect() {
  // Validate required values
  if (!this.documentIdValue && this.isOpenValue) {
    console.warn("Drawer opened without document ID")
  }
}
```

### 3. Error Boundaries
```ruby
def drawer_data_attributes
  {
    controller: "canvas-drawer",
    "canvas-drawer-document-id-value": document&.id || "",
    "canvas-drawer-has-errors-value": document&.errors&.any? || false
  }
rescue => e
  Rails.logger.error "Error generating drawer data: #{e.message}"
  { controller: "canvas-drawer" }
end
```

### 4. Testing Integration
```ruby
# component_test.rb
test "renders with correct stimulus data attributes" do
  component = Ui::CanvasDocuments::DrawerComponent.new(document: documents(:one))
  
  render_inline(component)
  
  assert_selector "[data-controller='canvas-drawer']"
  assert_selector "[data-canvas-drawer-document-id-value='#{documents(:one).id}']"
end
```

```javascript
// canvas_drawer_controller_test.js
test("connects with document data", () => {
  document.body.innerHTML = `
    <div data-controller="canvas-drawer"
         data-canvas-drawer-document-id-value="123">
    </div>
  `
  
  const application = Application.start()
  application.register("canvas-drawer", CanvasDrawerController)
  
  // Test controller initialization
})
```

## Related Patterns
- Component-Based Architecture
- Progressive Enhancement
- Server-Side Rendering with Client Hydration
- Data Down, Actions Up (React/Vue pattern)

## Tags
`viewcomponent` `stimulus` `rails` `integration` `server-rendering` `progressive-enhancement`

---
**Pattern ID**: viewcomponent-stimulus-integration-pattern  
**Created**: 2026-01-13  
**Language**: Ruby/Rails + JavaScript  
**Complexity**: Medium  
**Maturity**: Stable