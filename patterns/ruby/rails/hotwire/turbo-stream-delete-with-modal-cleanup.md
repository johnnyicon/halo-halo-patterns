---
id: pattern-ruby-rails-hotwire-turbo-stream-delete-modal-cleanup
title: Turbo Stream Delete with Modal/Drawer Cleanup
type: implementation
frameworks:
  - rails: ^7.0
  - hotwire/turbo: ^7.0
  - stimulus: ^3.0
tags:
  - turbo-streams
  - delete-action
  - modal-cleanup
  - optimistic-ui
  - broadcast
  - organization-scoped
created: 2026-01-15
updated: 2026-01-15
confidence: high
sanitized: true
---

# Turbo Stream Delete with Modal/Drawer Cleanup

## Context

When deleting records in Rails apps using Hotwire Turbo, you need to:
1. Remove the record from the database with proper cascade logic
2. Broadcast a Turbo Stream to remove the UI element (optimistic update)
3. Close any open modals/drawers that were displaying the deleted record
4. Update count badges or summary elements

This pattern shows how to handle deletes with complex cascade requirements (associations, file attachments, background jobs for external systems) while providing smooth UX with automatic modal cleanup and count updates.

**Problem:** Without proper Turbo Stream broadcasts and modal cleanup:
- Deleted record remains visible until page refresh
- Modal/drawer stays open showing stale data
- Count badges show outdated numbers
- Users confused about whether delete succeeded

**Solution:** Coordinate Rails destroy action with Turbo Stream broadcasts and Stimulus-based modal cleanup.

## When to Use

Use this pattern when:
- Deleting records that are displayed in list views with detail modals/drawers
- Need cascade deletion of associations, file attachments, or external system data
- Want optimistic UI updates (remove from list immediately)
- Using Hotwire Turbo Streams for real-time updates
- Need to close modals/drawers after successful delete
- Want to update count badges or summary stats after delete

Do NOT use this pattern if:
- Using traditional full-page reloads (stick with `redirect_to`)
- Not using Turbo Frames/Streams
- Delete is purely backend (no UI removal needed)
- Using soft deletes (status change, not actual destroy)

## Usage

### Step 1: Controller Destroy Action with Cascade Logic

```ruby
# app/controllers/ui/documents_controller.rb
module Ui
  class DocumentsController < ApplicationController
    # DELETE /ui/documents/:id
    def destroy
      @doc = Document.find(params[:id])

      # Authorization check (organization-scoped)
      unless @doc.org_id == current_organization&.id
        head :not_found
        return
      end

      # Transaction ensures atomicity
      ActiveRecord::Base.transaction do
        # 1. Enqueue background job for external system cleanup
        # (Do BEFORE destroy so we still have associations)
        doc_chunk_ids = @doc.doc_chunks.pluck(:id)
        DeleteEmbeddingsJob.perform_later(@doc.org_id, doc_chunk_ids) if doc_chunk_ids.any?

        # 2. Purge file attachments from storage
        @doc.source_file.purge if @doc.source_file.attached?

        # 3. Destroy record (Rails handles dependent: :destroy cascades)
        @doc.destroy!
      end

      # 4. Broadcast Turbo Stream to remove from list (optimistic UI)
      Turbo::StreamsChannel.broadcast_remove_to(
        "documents_org_#{@doc.org_id}",
        target: "document_#{@doc.id}"
      )

      # 5. Broadcast count update
      doc_count = Document.where(org_id: @doc.org_id).count
      Turbo::StreamsChannel.broadcast_replace_to(
        "documents_org_#{@doc.org_id}",
        target: "documents_count",
        partial: "ui/documents/count",
        locals: { doc_count: }
      )

      # 6. Respond with Turbo Stream to close modal/drawer
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.action(
            :dispatch_event,
            "drawer:close",  # Custom event Stimulus listens for
            detail: { document_id: @doc.id }
          )
        end
        format.html { redirect_to ui_documents_path, notice: "Document deleted." }
      end
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
  end
end
```

**Key Concepts:**
- **Transaction:** Ensures cascade steps are atomic (all succeed or all roll back)
- **Background Job First:** Enqueue before destroy so associations still exist
- **Purge Files:** Explicitly purge ActiveStorage attachments (not automatic)
- **Broadcast Remove:** Turbo Stream removes element from list (no refresh needed)
- **Broadcast Count:** Update summary stats in real-time
- **Custom Event:** Dispatch `drawer:close` for Stimulus to handle modal cleanup

### Step 2: Model Cascade Configuration

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  belongs_to :organization, foreign_key: :org_id
  belongs_to :context, optional: true

  # Cascade delete associations (Rails handles automatically on destroy)
  has_many :doc_versions, dependent: :destroy
  has_many :doc_chunks, through: :doc_versions, dependent: :destroy
  has_many :asset_doc_refs, dependent: :nullify  # or :destroy if orphans should be removed

  # File attachment
  has_one_attached :source_file

  validates :title, presence: true
  validates :org_id, presence: true
end
```

**Cascade Rules:**
1. `doc_versions` → `dependent: :destroy` (delete all versions)
2. `doc_chunks` → `dependent: :destroy` (through doc_versions, delete all chunks)
3. `asset_doc_refs` → `dependent: :nullify` (set foreign key to null, keep reference records)
4. `source_file` → Manual purge (ActiveStorage not automatic)
5. External embeddings → Background job (async, not blocking)

### Step 3: View Delete Button with Confirmation Dialog

```erb
<%# app/views/ui/documents/_detail_drawer.html.erb %>
<%= shadcn_sheet(open: true, data: { controller: "document-drawer", action: "drawer:close->document-drawer#close" }) do |sheet| %>
  <%= sheet.with_header do %>
    <h2 class="text-lg font-semibold"><%= @doc.title %></h2>
  <% end %>

  <%= sheet.with_body do %>
    <%# Document details... %>

    <%# Delete button with confirmation %>
    <%= shadcn_alert_dialog do |dialog| %>
      <%= dialog.with_trigger do %>
        <%= shadcn_button(variant: "destructive", size: "sm") do %>
          Delete Document
        <% end %>
      <% end %>

      <%= dialog.with_content do %>
        <%= dialog.with_header do %>
          <%= dialog.with_title { "Delete this document?" } %>
          <%= dialog.with_description do %>
            This will permanently remove:
            <ul class="list-disc ml-6 mt-2">
              <li>All versions (<%= @doc.doc_versions.count %> total)</li>
              <li>All chunks and embeddings</li>
              <li>The source file</li>
            </ul>
            <p class="mt-2 font-semibold">This action cannot be undone.</p>
          <% end %>
        <% end %>

        <%= dialog.with_footer do %>
          <%= dialog.with_cancel { "Cancel" } %>
          <%= dialog.with_action(variant: "destructive") do %>
            <%= button_to "Delete Document",
                ui_document_path(@doc),
                method: :delete,
                form: { data: { turbo_confirm: false } },  # Confirmation already shown
                class: "w-full" %>
          <% end %>
        <% end %>
      <% end %>
    <% end %>
  <% end %>
<% end %>
```

**Key Concepts:**
- **Confirmation Dialog:** shadcn AlertDialog shows cascade warning before delete
- **Destructive Variant:** Red button for dangerous action
- **Turbo Confirm False:** Disable default Rails confirmation (AlertDialog handles it)
- **Button To:** Rails `button_to` with `method: :delete` submits DELETE request via Turbo

### Step 4: List View with Stable Element IDs

```erb
<%# app/views/ui/documents/_list.html.erb %>
<%= turbo_stream_from "documents_org_#{current_organization.id}" %>

<div class="grid gap-4">
  <%= render partial: "ui/documents/count", locals: { doc_count: @docs.count } %>

  <% @docs.each do |doc| %>
    <div id="document_<%= doc.id %>" class="border rounded-lg p-4">
      <h3 class="font-semibold"><%= doc.title %></h3>
      <p class="text-sm text-muted-foreground"><%= doc.doc_versions.count %> versions</p>
      
      <%= link_to "View Details",
          drawer_content_ui_document_path(doc),
          data: { turbo_frame: "document_drawer", turbo_action: "advance" } %>
    </div>
  <% end %>
</div>
```

**Key Concepts:**
- **Stable ID:** `id="document_#{doc.id}"` matches broadcast target (critical for Turbo Stream)
- **Turbo Stream From:** Subscribe to broadcast channel for real-time updates
- **Count Partial:** Extracted so it can be replaced via Turbo Stream

### Step 5: Count Badge Partial (For Real-Time Updates)

```erb
<%# app/views/ui/documents/_count.html.erb %>
<div id="documents_count" class="flex items-center gap-2">
  <span class="text-sm font-medium">Documents:</span>
  <span class="badge"><%= doc_count %></span>
</div>
```

### Step 6: Stimulus Controller for Modal Cleanup

```javascript
// app/frontend/controllers/document_drawer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["shadcn--sheet"]  // Connect to shadcn sheet component

  // Listen for custom drawer:close event
  close(event) {
    // Close via outlet (preferred if connected)
    if (this.hasShadcnSheetOutlet) {
      this.shadcnSheetOutlet.close()
    }
    
    // Fallback: direct API call if outlet not connected
    if (this.element.hasAttribute("data-shadcn--sheet-open-value")) {
      this.element.setAttribute("data-shadcn--sheet-open-value", "false")
    }
  }
}
```

**Key Concepts:**
- **Outlets:** Stimulus outlets connect to shadcn Sheet controller
- **Custom Event:** Listen for `drawer:close` dispatched from Turbo Stream
- **Fallback:** Direct attribute manipulation if outlet not connected
- **Graceful Degradation:** Works even if component lifecycle differs

### Step 7: Background Job for External System Cleanup

```ruby
# app/jobs/delete_embeddings_job.rb
class DeleteEmbeddingsJob < ApplicationJob
  queue_as :default

  retry_on Pinecone::TimeoutError, wait: :polynomially_longer, attempts: 3
  retry_on Pinecone::RateLimitError, wait: :exponentially_longer, attempts: 5

  def perform(org_id, doc_chunk_ids)
    return if doc_chunk_ids.empty?

    organization = Organization.find(org_id)
    index = Pinecone::Index.new(name: organization.pinecone_index_name)

    # Batch delete embeddings (Pinecone supports up to 1000 IDs per request)
    doc_chunk_ids.each_slice(1000) do |batch|
      index.delete(ids: batch.map(&:to_s))
    end

    Rails.logger.info("Deleted #{doc_chunk_ids.count} embeddings for org #{org_id}")
  rescue Pinecone::NotFoundError => e
    # Index or vectors may already be deleted (idempotent)
    Rails.logger.warn("Pinecone vectors not found (already deleted?): #{e.message}")
  end
end
```

**Key Concepts:**
- **Async Execution:** Don't block delete action waiting for external API
- **Retry Logic:** Polynomially longer for transient errors
- **Batch Operations:** Pinecone supports up to 1000 IDs per request
- **Idempotency:** Handle NotFoundError gracefully (vectors may already be deleted)
- **Logging:** Track success/failure for audit trail

## Complete Flow

### Happy Path (Delete Success)

1. **User clicks "Delete Document" button**
   - shadcn AlertDialog opens with confirmation message
   - Shows cascade impact (versions, chunks, files)

2. **User confirms deletion**
   - Rails `button_to` submits DELETE request via Turbo
   - Request goes to `DocumentsController#destroy`

3. **Controller executes cascade logic**
   - Start transaction
   - Enqueue `DeleteEmbeddingsJob` (background)
   - Purge `source_file` from ActiveStorage
   - Destroy document record (Rails cascades to versions, chunks)
   - Transaction commits

4. **Turbo Stream broadcasts**
   - `broadcast_remove_to` removes `#document_{id}` from list (all clients)
   - `broadcast_replace_to` updates `#documents_count` badge (all clients)
   - Controller renders `drawer:close` event (current client only)

5. **Stimulus handles modal cleanup**
   - `document-drawer` controller receives `drawer:close` event
   - Calls `shadcnSheetOutlet.close()` to close drawer
   - User sees list updated, modal closed, count badge updated

6. **Background job completes**
   - `DeleteEmbeddingsJob` deletes vectors from Pinecone
   - Retries on transient errors
   - Logs success/failure

### Error Handling

**Authorization Failure:**
```ruby
unless @doc.org_id == current_organization&.id
  head :not_found  # Don't reveal doc exists
  return
end
```

**Record Not Found:**
```ruby
rescue ActiveRecord::RecordNotFound
  head :not_found
end
```

**Transaction Rollback:**
- If any step fails (enqueue, purge, destroy), entire transaction rolls back
- Document remains in database
- User sees error message (if HTML fallback) or retry prompt

**Background Job Failure:**
- Job retries on transient errors (timeouts, rate limits)
- If all retries exhausted, job moves to dead queue
- Document deleted from database (not rolled back)
- Orphaned embeddings in Pinecone (acceptable tradeoff)

## Tradeoffs

### Pros
- **Optimistic UI:** List updates immediately, no page refresh needed
- **Real-Time Sync:** All connected clients see updates via broadcast
- **Smooth UX:** Modal closes automatically after delete
- **Atomic Cascade:** Transaction ensures all-or-nothing deletion
- **Async External Cleanup:** Don't block user waiting for Pinecone API
- **Idempotent:** Can retry background job safely

### Cons
- **Complexity:** More moving parts than traditional `redirect_to`
- **Broadcast Dependency:** Requires Turbo Streams setup (ActionCable or SSE)
- **Race Conditions:** If user opens same doc in multiple tabs, stale data possible
- **Failed Background Job:** Orphaned embeddings if all retries fail
- **Debugging:** Harder to trace issues across broadcasts + jobs + Stimulus

### When NOT to Use
- **Traditional Apps:** If not using Hotwire Turbo, stick with `redirect_to`
- **Simple Deletes:** No associations, no files → use standard Rails destroy + redirect
- **Soft Deletes:** If using status flags (not actual destroy), don't need Turbo Stream remove
- **No Modal/Drawer:** If delete happens on index page (no modal to close), simpler pattern works

## Verification Checklist

**Before Declaring Complete:**
- [ ] Authorization check: Only organization members can delete
- [ ] Transaction wraps all cascade steps
- [ ] Background job enqueued BEFORE destroy
- [ ] File attachments purged explicitly
- [ ] Record destroyed (not just status changed)
- [ ] `broadcast_remove_to` removes correct element ID
- [ ] `broadcast_replace_to` updates count badge
- [ ] `drawer:close` event dispatched to close modal
- [ ] Stable element IDs in list view (`id="document_#{id}"`)
- [ ] `turbo_stream_from` subscription in list view
- [ ] Count partial extracted for replacement
- [ ] Stimulus controller handles `drawer:close` event
- [ ] Outlets connect to shadcn Sheet controller
- [ ] Confirmation dialog shows cascade impact
- [ ] Background job has retry logic
- [ ] Background job is idempotent (handles NotFoundError)
- [ ] Error handling for authorization, not found, rollback

**Runtime Verification (Browser Testing):**
- [ ] Open document drawer
- [ ] Click "Delete Document"
- [ ] Confirmation dialog appears with cascade details
- [ ] Click "Cancel" → dialog closes, document not deleted
- [ ] Click "Delete Document" again → confirm
- [ ] Document removed from list immediately
- [ ] Count badge updates immediately
- [ ] Drawer closes automatically
- [ ] Refresh page → document still deleted
- [ ] Check logs → background job enqueued
- [ ] Open in multiple tabs → all tabs see update
- [ ] Test cross-org access → returns 404

## Testing Strategy

### System Test (Capybara + Playwright)

```ruby
# test/system/documents/delete_test.rb
require "application_system_test_case"

class Documents::DeleteTest < ApplicationSystemTestCase
  setup do
    @org = organizations(:acme)
    @doc = docs(:report)
    
    # Stub external API
    DeleteEmbeddingsJob.any_instance.stubs(:perform).returns(true)
  end

  test "deletes document with confirmation" do
    visit ui_documents_path

    # Open drawer
    click_on @doc.title
    assert_selector "h2", text: @doc.title

    # Click delete
    click_on "Delete Document"

    # Confirmation dialog appears
    assert_selector "h3", text: "Delete this document?"
    assert_text "All versions"
    assert_text "This action cannot be undone"

    # Confirm deletion
    within "div[role='alertdialog']" do
      click_on "Delete Document"
    end

    # Verify UI updates
    refute_selector "#document_#{@doc.id}"  # Removed from list
    refute_selector "h2", text: @doc.title  # Drawer closed

    # Verify database
    assert_nil Doc.find_by(id: @doc.id)
    assert_equal 0, DocVersion.where(doc_id: @doc.id).count
  end

  test "cancels deletion" do
    visit ui_documents_path
    click_on @doc.title
    click_on "Delete Document"

    # Cancel
    within "div[role='alertdialog']" do
      click_on "Cancel"
    end

    # Document still exists
    assert_selector "#document_#{@doc.id}"
    assert Doc.find_by(id: @doc.id)
  end

  test "prevents cross-org deletion" do
    other_org_doc = docs(:other_org_report)

    # Try to delete via direct request
    delete ui_document_path(other_org_doc)
    assert_response :not_found

    # Document still exists
    assert Doc.find_by(id: other_org_doc.id)
  end
end
```

### Controller Test

```ruby
# test/controllers/ui/documents_controller_test.rb
require "test_helper"

class Ui::DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @org = organizations(:acme)
    @doc = docs(:report)
    @doc.update!(org_id: @org.id)
    
    # Stub background job
    DeleteEmbeddingsJob.stubs(:perform_later).returns(true)
  end

  test "destroys document and broadcasts removal" do
    assert_difference "Doc.count", -1 do
      delete ui_document_path(@doc), as: :turbo_stream
    end

    assert_response :success
    assert_nil Doc.find_by(id: @doc.id)
  end

  test "prevents cross-org deletion" do
    other_org = organizations(:other)
    @doc.update!(org_id: other_org.id)

    assert_no_difference "Doc.count" do
      delete ui_document_path(@doc), as: :turbo_stream
    end

    assert_response :not_found
    assert Doc.find_by(id: @doc.id)  # Still exists
  end

  test "enqueues background job for embeddings" do
    DeleteEmbeddingsJob.unstub(:perform_later)
    assert_enqueued_with job: DeleteEmbeddingsJob do
      delete ui_document_path(@doc), as: :turbo_stream
    end
  end
end
```

### Job Test

```ruby
# test/jobs/delete_embeddings_job_test.rb
require "test_helper"

class DeleteEmbeddingsJobTest < ActiveJob::TestCase
  setup do
    @org = organizations(:acme)
    @chunk_ids = [SecureRandom.uuid, SecureRandom.uuid]
  end

  test "deletes embeddings from Pinecone" do
    index_mock = mock("index")
    index_mock.expects(:delete).with(ids: @chunk_ids.map(&:to_s))
    
    Pinecone::Index.stubs(:new).returns(index_mock)

    DeleteEmbeddingsJob.perform_now(@org.id, @chunk_ids)
  end

  test "handles NotFoundError gracefully" do
    index_mock = mock("index")
    index_mock.stubs(:delete).raises(Pinecone::NotFoundError, "Index not found")
    
    Pinecone::Index.stubs(:new).returns(index_mock)

    # Should not raise error
    assert_nothing_raised do
      DeleteEmbeddingsJob.perform_now(@org.id, @chunk_ids)
    end
  end

  test "batches large deletions" do
    large_batch = (1..2500).map { SecureRandom.uuid }
    
    index_mock = mock("index")
    index_mock.expects(:delete).times(3)  # 3 batches of 1000
    
    Pinecone::Index.stubs(:new).returns(index_mock)

    DeleteEmbeddingsJob.perform_now(@org.id, large_batch)
  end
end
```

## Performance Considerations

**Transaction Duration:**
- Keep transaction short (< 100ms typical)
- Enqueue job first (fast, just DB insert)
- Purge file second (fast, just metadata update)
- Destroy record third (fast with proper indexes)

**Broadcast Latency:**
- ActionCable: ~50-200ms typical
- SSE: ~100-500ms typical
- All connected clients receive updates

**Background Job Latency:**
- Queued immediately (< 10ms)
- Executes async (1-5 seconds typical)
- User doesn't wait for Pinecone API

**Database Cascade:**
- `dependent: :destroy` triggers N+1 callbacks
- For large associations (1000+ versions), consider batch delete
- Add indexes on foreign keys (`doc_id`, `org_id`)

**Optimization Tips:**
1. **Batch Background Jobs:** If deleting many docs, collect all chunk IDs and enqueue once
2. **Skip Callbacks:** Use `delete_all` for associations if no callbacks needed
3. **Soft Delete:** For large datasets, mark as deleted (status flag) instead of destroying
4. **Async File Purge:** Move `purge` to background job if storage is slow

## Security Considerations

**Authorization:**
```ruby
unless @doc.org_id == current_organization&.id
  head :not_found  # Don't reveal doc exists
  return
end
```

**CSRF Protection:**
- Rails `button_to` with `method: :delete` includes authenticity token
- Turbo respects CSRF protection automatically

**Prevent Cascade Bugs:**
- Use `dependent: :destroy` (not `dependent: :delete_all` which skips callbacks)
- Explicitly purge file attachments (not automatic)
- Test cascade in isolation (factory creates full association tree)

**Audit Trail:**
- Log deletions: `Rails.logger.info("User deleted doc #{@doc.id}")`
- Consider soft delete for sensitive records (status flag instead of destroy)
- Background job logs success/failure for compliance

## Real-World Use Cases

### Use Case 1: Document Management System
User uploads report, realizes it's wrong file, deletes from drawer. System removes document, all versions, chunks, embeddings, and source file. List updates immediately, count badge shows new total, drawer closes.

### Use Case 2: Multi-Tab Scenario
User opens doc in two tabs. Deletes in Tab 1. Both tabs see list update via broadcast. Tab 2's drawer closes automatically (Turbo Stream). User sees consistent state across tabs.

### Use Case 3: Failed Background Job
User deletes doc with 10,000 embeddings. Pinecone API times out after 3 retries. Job moves to dead queue. Document deleted from database (user sees success). DevOps reviews dead queue, manually re-enqueues job later.

### Use Case 4: Cross-Org Security Test
Attacker guesses doc ID from another org. Submits DELETE request. Controller checks `org_id`, returns 404. Document not deleted, no info leaked.

## Related Patterns

- **[Soft Delete with Status Flag](#)** - Alternative to hard delete for audit trail
- **[Turbo Frame Navigation](#)** - How to navigate within frames
- **[Stimulus Outlets](#)** - How to connect Stimulus controllers
- **[ActionCable Broadcasting](#)** - How to broadcast to multiple clients
- **[Background Job Retry Strategies](#)** - How to handle transient failures

## References

- [Hotwire Turbo Streams Documentation](https://turbo.hotwired.dev/handbook/streams)
- [Rails ActiveRecord Callbacks](https://guides.rubyonrails.org/active_record_callbacks.html)
- [Stimulus Outlets Guide](https://stimulus.hotwired.dev/reference/outlets)
- [ActiveStorage File Attachments](https://edgeguides.rubyonrails.org/active_storage_overview.html)
- [ActionCable Broadcasting](https://guides.rubyonrails.org/action_cable_overview.html#broadcasting)

---

**Pattern Author Notes:**

This pattern was extracted from PRD_10 (Document Drawer Improvements) where we needed to add delete functionality to a Hotwire Turbo-based Rails app. The key insights:

1. **Transaction ensures atomicity** - All cascade steps succeed or all roll back
2. **Enqueue before destroy** - Background job needs associations to exist
3. **Broadcast order matters** - Remove element, update count, close modal
4. **Stable IDs critical** - `id="document_#{id}"` must match broadcast target
5. **Stimulus outlets for modal cleanup** - Custom event triggers close
6. **Idempotent background jobs** - Handle NotFoundError gracefully

The pattern evolved through testing: initially forgot to purge files, discovered race condition with background job timing, learned that Turbo Stream `dispatch_event` is cleaner than JavaScript injection.

**Common Pitfalls Avoided:**
- ❌ Destroying record before enqueuing job (associations gone)
- ❌ Forgetting to purge file attachments (orphaned files)
- ❌ Not broadcasting count update (stale badge)
- ❌ Using `delete_all` (skips callbacks and cascades)
- ❌ Hardcoding modal close (breaks with portals)

**Testing Gotchas:**
- System tests need Turbo Stream subscription to see broadcasts
- Stub background jobs or tests timeout waiting for Pinecone
- Test cross-org security (attackers will try guessing IDs)
- Verify modal closes (Stimulus timing issues possible)

---

**Confidence Level: HIGH** - Pattern tested in production, handles edge cases, proven with Capybara + Playwright system tests.
