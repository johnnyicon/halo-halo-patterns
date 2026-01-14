---
id: "pattern-javascript-stimulus-stateful-ui-localstorage"
title: "Stateful UI Component with Local Storage Backup Pattern"
type: implementation
status: draft
confidence: high
revision: 1
languages:
  - javascript
frameworks:
  - stimulus
dependencies:
  - stimulus
domain: state_management
tags:
  - stimulus
  - localstorage
  - state-management
  - crash-recovery
  - dirty-state
  - autosave
introduced: 2026-01-13
last_verified: 2026-01-13
review_by: 2026-04-13
sanitized: true
related:
  - pattern-ruby-rails-stimulus-outlets
---

# Stateful UI Component with Local Storage Backup Pattern

## Summary
Pattern for managing complex UI component state with explicit save actions, dirty state tracking, and localStorage backup for crash recovery.

## Context
Building rich editing interfaces or complex forms where users make changes over time, need clear feedback about save state, and should not lose work due to browser crashes or accidental navigation.

## Problem
- Users need to know if their changes are saved or pending
- Browser crashes or accidental tab closure cause data loss
- Autosave can be confusing or conflict with user intentions
- Complex state management across multiple UI interactions

## Solution

### Core State Management Controller
```javascript
// app/frontend/controllers/canvas_drawer_controller.js
export default class extends Controller {
  static targets = ["editor", "saveButton", "saveStatus", "title"]
  
  static values = {
    documentId: String,
    isOpen: Boolean,
    isDirty: Boolean,
    isLoading: Boolean,
    lastSaved: String
  }

  // Lifecycle
  connect() {
    console.log("[canvas-drawer] connect")
    this.setupEditor()
    this.setupBeforeUnload()
    this.setupKeyboardShortcuts()
    this.restoreFromBackup()
  }

  disconnect() {
    this.destroyEditor()
    this.removeEventListeners()
    this.clearBackup()
  }

  // === State Management ===

  // Automatically called when values change
  isDirtyValueChanged() {
    this.updateSaveStatus()
    this.updateBackup()
  }

  isLoadingValueChanged() {
    this.updateSaveButton()
  }

  documentIdValueChanged() {
    if (this.documentIdValue) {
      this.loadDocument()
    }
  }

  // === Content Management ===

  markDirty() {
    if (!this.isDirtyValue) {
      this.isDirtyValue = true
      console.log("[canvas-drawer] marked dirty")
    }
  }

  markClean() {
    this.isDirtyValue = false
    this.lastSavedValue = new Date().toISOString()
    console.log("[canvas-drawer] marked clean")
  }

  // === Save Operations ===

  async save() {
    if (!this.isDirtyValue || this.isLoadingValue) return

    this.isLoadingValue = true
    
    try {
      const content = this.getEditorContent()
      const title = this.titleTarget.value

      const response = await fetch(`/ui/canvas_documents/${this.documentIdValue}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          body_markdown: content,
          title: title,
          expected_version: this.currentVersion
        })
      })

      if (response.ok) {
        const data = await response.json()
        this.handleSaveSuccess(data)
      } else if (response.status === 409) {
        this.handleConflict(await response.json())
      } else {
        throw new Error(`Save failed: ${response.statusText}`)
      }
    } catch (error) {
      console.error("[canvas-drawer] Save failed:", error)
      this.showError("Save failed. Your work is backed up locally.")
    } finally {
      this.isLoadingValue = false
    }
  }

  handleSaveSuccess(data) {
    this.markClean()
    this.currentVersion = data.version_number
    this.clearBackup()
    this.showSuccess("Saved successfully")
  }

  // === Local Storage Backup ===

  updateBackup() {
    if (!this.isDirtyValue) return

    const backup = {
      documentId: this.documentIdValue,
      title: this.titleTarget?.value || "",
      content: this.getEditorContent(),
      timestamp: Date.now(),
      version: this.currentVersion
    }

    localStorage.setItem(this.backupKey, JSON.stringify(backup))
    console.log("[canvas-drawer] backup saved")
  }

  restoreFromBackup() {
    const backupData = localStorage.getItem(this.backupKey)
    if (!backupData) return

    try {
      const backup = JSON.parse(backupData)
      
      // Only restore if for same document and recent
      if (backup.documentId === this.documentIdValue && 
          this.isRecentBackup(backup.timestamp)) {
        
        this.showRestorePrompt(backup)
      }
    } catch (error) {
      console.error("[canvas-drawer] Backup restore failed:", error)
      this.clearBackup()
    }
  }

  showRestorePrompt(backup) {
    const message = `Found unsaved changes from ${this.formatTimestamp(backup.timestamp)}. Restore them?`
    
    if (confirm(message)) {
      this.titleTarget.value = backup.title
      this.setEditorContent(backup.content)
      this.markDirty()
      this.showInfo("Unsaved changes restored")
    } else {
      this.clearBackup()
    }
  }

  clearBackup() {
    localStorage.removeItem(this.backupKey)
  }

  get backupKey() {
    return `canvas_drawer_backup_${this.documentIdValue}`
  }

  isRecentBackup(timestamp) {
    const fiveMinutesAgo = Date.now() - (5 * 60 * 1000)
    return timestamp > fiveMinutesAgo
  }

  // === UI State Updates ===

  updateSaveStatus() {
    if (!this.hasSaveStatusTarget) return

    if (this.isLoadingValue) {
      this.saveStatusTarget.textContent = "Saving..."
      this.saveStatusTarget.className = "text-blue-600"
    } else if (this.isDirtyValue) {
      this.saveStatusTarget.textContent = "Unsaved changes"
      this.saveStatusTarget.className = "text-amber-600"
    } else {
      const lastSaved = this.lastSavedValue ? 
        this.formatTimestamp(this.lastSavedValue) : 
        "just now"
      this.saveStatusTarget.textContent = `Saved ${lastSaved}`
      this.saveStatusTarget.className = "text-green-600"
    }
  }

  updateSaveButton() {
    if (!this.hasSaveButtonTarget) return

    this.saveButtonTarget.disabled = !this.isDirtyValue || this.isLoadingValue
    this.saveButtonTarget.textContent = this.isLoadingValue ? "Saving..." : "Save"
  }

  // === Browser Integration ===

  setupBeforeUnload() {
    this._beforeUnloadHandler = (event) => {
      if (this.isDirtyValue) {
        event.preventDefault()
        event.returnValue = "You have unsaved changes. Are you sure you want to leave?"
        return event.returnValue
      }
    }
    window.addEventListener("beforeunload", this._beforeUnloadHandler)
  }

  setupKeyboardShortcuts() {
    this._keydownHandler = (event) => {
      // Cmd/Ctrl + S to save
      if ((event.metaKey || event.ctrlKey) && event.key === "s") {
        event.preventDefault()
        this.save()
      }
    }
    document.addEventListener("keydown", this._keydownHandler)
  }

  removeEventListeners() {
    if (this._beforeUnloadHandler) {
      window.removeEventListener("beforeunload", this._beforeUnloadHandler)
    }
    if (this._keydownHandler) {
      document.removeEventListener("keydown", this._keydownHandler)
    }
  }

  // === Editor Integration ===

  setupEditor() {
    // Initialize TipTap or other editor
    this.editor = new Editor({
      element: this.editorTarget,
      content: this.initialContent,
      onUpdate: () => {
        this.markDirty()
      }
    })
  }

  getEditorContent() {
    return this.editor?.getHTML() || this.editorTarget.innerHTML
  }

  setEditorContent(content) {
    if (this.editor) {
      this.editor.commands.setContent(content)
    } else {
      this.editorTarget.innerHTML = content
    }
  }

  // === Utility Methods ===

  formatTimestamp(timestamp) {
    const date = new Date(timestamp)
    const now = new Date()
    const diffMs = now - date
    const diffMins = Math.floor(diffMs / 60000)

    if (diffMins < 1) return "just now"
    if (diffMins < 60) return `${diffMins}m ago`
    if (diffMins < 1440) return `${Math.floor(diffMins / 60)}h ago`
    return date.toLocaleDateString()
  }

  showSuccess(message) {
    this.showNotification(message, "success")
  }

  showError(message) {
    this.showNotification(message, "error")
  }

  showInfo(message) {
    this.showNotification(message, "info")
  }

  showNotification(message, type = "info") {
    // Implement your notification system
    console.log(`[${type}] ${message}`)
  }

  get csrfToken() {
    return document.querySelector("[name='csrf-token']")?.content
  }
}
```

### ViewComponent Template Integration
```erb
<!-- app/components/ui/canvas_documents/drawer_component.html.erb -->
<div data-controller="canvas-drawer"
     data-canvas-drawer-document-id-value="<%= document&.id %>"
     data-canvas-drawer-is-dirty-value="false"
     data-canvas-drawer-last-saved-value="<%= document&.updated_at&.iso8601 %>">

  <!-- Header with save status -->
  <header class="flex items-center justify-between p-4 border-b">
    <input type="text" 
           value="<%= document&.title || 'Untitled Document' %>"
           data-canvas-drawer-target="title"
           data-action="input->canvas-drawer#markDirty"
           class="text-lg font-medium bg-transparent border-none outline-none">
    
    <div class="flex items-center gap-3">
      <!-- Save status indicator -->
      <span data-canvas-drawer-target="saveStatus" class="text-sm text-green-600">
        Saved
      </span>
      
      <!-- Save button -->
      <button type="button"
              data-canvas-drawer-target="saveButton"
              data-action="click->canvas-drawer#save"
              class="px-3 py-1 bg-blue-600 text-white rounded disabled:opacity-50">
        Save
      </button>
    </div>
  </header>

  <!-- Editor -->
  <div class="flex-1 p-4">
    <div data-canvas-drawer-target="editor"
         data-action="input->canvas-drawer#markDirty"
         class="min-h-full prose max-w-none">
      <%= document&.body_markdown %>
    </div>
  </div>
</div>
```

### Conflict Resolution Extension
```javascript
// Extend the base controller for conflict handling
handleConflict(conflictData) {
  // Show conflict resolution dialog
  document.dispatchEvent(new CustomEvent("canvas-document:conflict", {
    detail: {
      serverContent: conflictData.current_content,
      localContent: this.getEditorContent(),
      serverVersion: conflictData.version_number,
      localVersion: this.currentVersion
    }
  }))
}

// Handle force save from conflict dialog
setupForceSaveListener() {
  this._forceSaveHandler = (event) => {
    if (event.detail.documentId === this.documentIdValue) {
      this.forceSave()
    }
  }
  document.addEventListener("canvas-document:force-save", this._forceSaveHandler)
}

async forceSave() {
  // Save without version check
  this.isLoadingValue = true
  
  try {
    const response = await fetch(`/ui/canvas_documents/${this.documentIdValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({
        body_markdown: this.getEditorContent(),
        title: this.titleTarget.value,
        force_overwrite: true
      })
    })

    if (response.ok) {
      this.handleSaveSuccess(await response.json())
    }
  } finally {
    this.isLoadingValue = false
  }
}
```

## Benefits
- **Data Safety**: localStorage backup prevents data loss
- **User Clarity**: Clear visual feedback about save state
- **Performance**: Explicit save prevents unnecessary API calls
- **User Control**: Users decide when to save changes
- **Crash Recovery**: Automatic restoration of unsaved work

## When to Use
- ✅ Rich text editors and complex forms
- ✅ Long-form content editing
- ✅ Applications where data loss would be catastrophic
- ✅ Multi-step workflows with temporary state

## When NOT to Use
- ❌ Simple forms with quick submissions
- ❌ Real-time collaborative editing (needs different approach)
- ❌ High-frequency data updates
- ❌ Purely read-only interfaces

## Trade-offs
**Pros:**
- Excellent user experience for content editing
- Robust data protection
- Clear mental model for users
- Works well with server-side validation

**Cons:**
- More complex than simple autosave
- Requires localStorage (privacy/storage concerns)
- Additional state management complexity
- Not suitable for real-time collaboration

## Implementation Tips

### 1. Throttle Backup Updates
```javascript
markDirty() {
  if (!this.isDirtyValue) {
    this.isDirtyValue = true
    
    // Throttle backup updates
    clearTimeout(this.backupTimeout)
    this.backupTimeout = setTimeout(() => {
      this.updateBackup()
    }, 1000)
  }
}
```

### 2. Graceful localStorage Handling
```javascript
safeSetItem(key, value) {
  try {
    localStorage.setItem(key, value)
  } catch (error) {
    if (error.name === 'QuotaExceededError') {
      console.warn("localStorage quota exceeded, clearing old backups")
      this.clearOldBackups()
      // Retry
      localStorage.setItem(key, value)
    }
  }
}
```

### 3. Multiple Document Support
```javascript
get backupKey() {
  return `canvas_drawer_backup_${this.documentIdValue}_${this.userId || 'anonymous'}`
}

clearOldBackups() {
  const prefix = 'canvas_drawer_backup_'
  Object.keys(localStorage)
    .filter(key => key.startsWith(prefix))
    .forEach(key => {
      try {
        const backup = JSON.parse(localStorage.getItem(key))
        if (!this.isRecentBackup(backup.timestamp)) {
          localStorage.removeItem(key)
        }
      } catch {
        localStorage.removeItem(key)
      }
    })
}
```

## Related Patterns
- Command Pattern (for undo/redo)
- Observer Pattern (for state change notifications)  
- Optimistic UI Updates
- Offline-First Applications

## Tags
`state-management` `localStorage` `auto-save` `data-protection` `stimulus` `ui-patterns`

---
**Pattern ID**: stateful-ui-localstorage-backup-pattern  
**Created**: 2026-01-13  
**Language**: JavaScript/Stimulus  
**Complexity**: Medium-High  
**Maturity**: Stable