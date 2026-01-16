---
id: "pattern-ruby-rails-active-record-document-status-swap-unique-constraint"
title: "Rails Document Status Swap with Partial Unique Index"
type: implementation
status: draft
confidence: high
revision: 1
languages:
  - language: ruby
    versions: ">=3.0"
frameworks:
  - name: rails
    versions: ">=7.0 <9.0"
  - name: active_record
    versions: ">=7.0"
dependencies: []
domain: active_record
tags:
  - versioning
  - unique-constraints
  - transactions
  - status-transitions
  - partial-index
introduced: 2026-01-15
last_verified: 2026-01-15
review_by: 2026-04-15
sanitized: true
related:
  - pattern-ruby-rails-active-record-optimistic-locking
  - pattern-ruby-rails-transactions-isolation-levels
---

# Rails Document Status Swap with Partial Unique Index

## Context

When implementing document versioning systems where only one version can be "current" at a time, you need:

1. **Atomic status transition** - Prevent race conditions when swapping current/superseded status
2. **Database-enforced uniqueness** - Ensure only one "current" version per document
3. **Clean state transitions** - Avoid violating unique constraints during the swap

Common scenario: Publishing a new version requires marking the old "current" version as "superseded" and the new version as "current", all atomically.

**Problem:** If you have a unique index on `(doc_id)` where `status = 'current'`, you cannot directly update both rows without temporarily violating the constraint.

**Solution:** Use a three-step status transition pattern with a partial unique index and transaction isolation.

## Usage

### Step 1: Define Status States and Partial Unique Index

**Migration:**

```ruby
class CreateDocumentVersions < ActiveRecord::Migration[7.0]
  def change
    create_table :document_versions, id: :uuid do |t|
      t.uuid :document_id, null: false
      t.string :status, null: false, default: "current"
      t.uuid :superseded_by_id  # Points to the version that replaced this one
      t.text :content, null: false

      t.timestamps
    end

    add_foreign_key :document_versions, :documents, column: :document_id
    add_foreign_key :document_versions, :document_versions, column: :superseded_by_id
    
    add_index :document_versions, :status

    # CRITICAL: Partial unique index - only enforces uniqueness for 'current' status
    add_index :document_versions, :document_id, 
              unique: true, 
              where: "status = 'current'"

    # Integrity check: superseded versions must reference their successor
    execute <<~SQL
      ALTER TABLE document_versions
      ADD CONSTRAINT document_versions_supersession_integrity
      CHECK (
        (status = 'superseded' AND superseded_by_id IS NOT NULL) OR
        (status != 'superseded')
      );
    SQL
  end
end
```

**Status states:**
- `pending` - New version not yet published (does not appear in partial unique index)
- `current` - Active version (subject to unique constraint via partial index)
- `superseded` - Replaced by a newer version (no longer in partial unique index)

### Step 2: Implement Three-Step Status Swap Service

**Service class:**

```ruby
module Documents
  class PublishVersion
    def self.call(document_id:, content:)
      result = nil

      ActiveRecord::Base.transaction do
        document = Document.find(document_id)
        previous_current = DocumentVersion.find_by(
          document_id: document.id, 
          status: "current"
        )

        if previous_current.nil?
          # First version - directly create as 'current'
          new_version = DocumentVersion.create!(
            document: document,
            status: "current",
            content: content
          )
          result = { version: new_version, superseded: nil }
        else
          # THREE-STEP SWAP to avoid unique constraint violation:
          
          # Step 1: Create new version as 'pending' (outside unique constraint)
          new_version = DocumentVersion.create!(
            document: document,
            status: "pending",
            content: content
          )

          # Step 2: Mark previous 'current' as 'superseded' (removes from constraint)
          previous_current.update!(
            status: "superseded",
            superseded_by_id: new_version.id
          )

          # Step 3: Promote 'pending' to 'current' (now safe, no conflict)
          new_version.update!(status: "current")

          result = { version: new_version, superseded: previous_current }
        end
      end

      result
    end
  end
end
```

**Why this works:**
1. New version starts as `pending` (not subject to unique index)
2. Old `current` becomes `superseded` (removed from unique index scope)
3. New version becomes `current` (now only one `current` exists)

Each step maintains the partial unique constraint without conflicts.

### Step 3: Model Associations

**Document model:**

```ruby
class Document < ApplicationRecord
  has_many :document_versions, dependent: :destroy
  has_one :current_version, 
          -> { where(status: "current") }, 
          class_name: "DocumentVersion",
          inverse_of: :document

  validates :title, presence: true
end
```

**DocumentVersion model:**

```ruby
class DocumentVersion < ApplicationRecord
  belongs_to :document
  belongs_to :superseded_by, 
             class_name: "DocumentVersion", 
             optional: true

  has_many :supersedes, 
           class_name: "DocumentVersion", 
           foreign_key: :superseded_by_id,
           dependent: :nullify

  validates :status, inclusion: { in: %w[pending current superseded] }
  validates :content, presence: true

  # Ensure only one 'current' per document (redundant with DB constraint, but good practice)
  validates :status, uniqueness: { 
    scope: :document_id, 
    conditions: -> { where(status: "current") },
    message: "only one current version allowed per document"
  }, if: -> { status == "current" }

  scope :current, -> { where(status: "current") }
  scope :superseded, -> { where(status: "superseded") }
  scope :pending, -> { where(status: "pending") }
end
```

### Step 4: Controller Integration

**Controller action:**

```ruby
class DocumentsController < ApplicationController
  def publish_version
    @document = current_organization.documents.find(params[:id])
    
    result = Documents::PublishVersion.call(
      document_id: @document.id,
      content: params[:content]
    )

    if result[:version].persisted?
      flash[:notice] = "Version published successfully"
      redirect_to document_path(@document)
    else
      flash[:alert] = "Failed to publish version"
      render :edit, status: :unprocessable_entity
    end
  end
end
```

### Step 5: Query Patterns

**Fetching current version:**

```ruby
# Preferred: Use association
document.current_version

# Alternative: Direct query
DocumentVersion.find_by(document_id: document.id, status: "current")
```

**Fetching version history:**

```ruby
# All versions ordered by creation
document.document_versions.order(created_at: :desc)

# Only superseded versions
document.document_versions.superseded.order(created_at: :desc)

# Version chain (follow supersession links)
def version_chain(version)
  chain = [version]
  while version.superseded_by
    version = version.superseded_by
    chain << version
  end
  chain
end
```

### Step 6: Testing

**Test status swap integrity:**

```ruby
require "test_helper"

class Documents::PublishVersionTest < ActiveSupport::TestCase
  test "publishes first version as current" do
    document = documents(:one)
    
    result = Documents::PublishVersion.call(
      document_id: document.id,
      content: "# First Version"
    )

    assert result[:version].persisted?
    assert_equal "current", result[:version].status
    assert_nil result[:superseded]
  end

  test "swaps current to superseded when publishing new version" do
    document = documents(:one)
    first = DocumentVersion.create!(
      document: document,
      status: "current",
      content: "# First"
    )

    result = Documents::PublishVersion.call(
      document_id: document.id,
      content: "# Second Version"
    )

    # New version is current
    assert_equal "current", result[:version].status
    assert_equal "# Second Version", result[:version].content

    # Old version is superseded
    assert_equal "superseded", result[:superseded].status
    assert_equal result[:version].id, result[:superseded].superseded_by_id

    # Only one current version exists
    assert_equal 1, document.document_versions.current.count
  end

  test "enforces unique current constraint at database level" do
    document = documents(:one)
    DocumentVersion.create!(document: document, status: "current", content: "# V1")

    # Attempting to create a second 'current' version directly violates constraint
    assert_raises(ActiveRecord::RecordNotUnique) do
      DocumentVersion.create!(document: document, status: "current", content: "# V2")
    end
  end

  test "allows multiple pending versions" do
    document = documents(:one)
    
    # Multiple pending versions are allowed (not subject to unique constraint)
    v1 = DocumentVersion.create!(document: document, status: "pending", content: "# P1")
    v2 = DocumentVersion.create!(document: document, status: "pending", content: "# P2")

    assert v1.persisted?
    assert v2.persisted?
  end

  test "atomic swap prevents race conditions" do
    document = documents(:one)
    DocumentVersion.create!(document: document, status: "current", content: "# V1")

    # Simulate concurrent publishes
    threads = 10.times.map do
      Thread.new do
        Documents::PublishVersion.call(
          document_id: document.id,
          content: "# Concurrent Version #{Thread.current.object_id}"
        )
      end
    end

    threads.each(&:join)

    # Only one 'current' version should exist after all threads complete
    assert_equal 1, document.document_versions.current.count
  end
end
```

## Tradeoffs

### Pros

- **Database-enforced uniqueness** - Partial index prevents data corruption
- **Atomic transitions** - Transaction ensures all-or-nothing swap
- **No constraint violations** - Three-step pattern avoids temporary conflicts
- **Referential integrity** - Foreign key to superseded_by prevents orphaned references
- **Query efficiency** - Partial index makes fetching current version fast

### Cons

- **Three updates required** - More database round trips than single update
- **Transaction overhead** - Locks involved during swap (mitigated by short transaction)
- **Pending state complexity** - Must handle pending versions in application logic
- **Migration complexity** - Partial unique indexes require database support (PostgreSQL, MySQL 8.0+)

### When to Use

- ✅ Document versioning systems (CMS, wikis, proposals)
- ✅ Configuration management (settings, feature flags)
- ✅ Approval workflows (only one "approved" version)
- ✅ Multi-tenant systems with per-org current versions

### When NOT to Use

- ❌ Simple timestamp-based versioning (no unique constraint needed)
- ❌ Multi-current systems (multiple active versions allowed)
- ❌ Event sourcing patterns (append-only, no updates)
- ❌ Databases without partial unique index support

## Verification Checklist

### Database Constraints
- [ ] Partial unique index on `(document_id)` where `status = 'current'`
- [ ] Foreign key on `superseded_by_id` references `document_versions(id)`
- [ ] Check constraint: superseded versions must have `superseded_by_id`
- [ ] Status column has NOT NULL constraint

### Service Implementation
- [ ] Uses transaction to wrap entire swap operation
- [ ] Creates new version as 'pending' first
- [ ] Updates old current to 'superseded' with superseded_by_id
- [ ] Promotes pending to 'current' last
- [ ] Handles first version case (no previous current)

### Model Validations
- [ ] Status in ['pending', 'current', 'superseded']
- [ ] Content presence validation
- [ ] Associations defined correctly (document, superseded_by, supersedes)

### Query Patterns
- [ ] current_version association uses where(status: 'current')
- [ ] Scopes defined for current, superseded, pending
- [ ] Version history queries ordered by created_at

### Testing
- [ ] Test first version publish
- [ ] Test status swap (current → superseded, pending → current)
- [ ] Test unique constraint enforcement
- [ ] Test concurrent publishes (race condition prevention)
- [ ] Test supersession chain traversal

### Edge Cases
- [ ] Publishing identical content (creates new version anyway)
- [ ] Publishing while background jobs reference old current version
- [ ] Deleting a document with superseded versions
- [ ] Manually updating status (bypassing service) causes corruption

## Performance Considerations

### Index Strategy

**Partial unique index benefits:**
```sql
-- Fast lookup for current version (uses index)
SELECT * FROM document_versions 
WHERE document_id = ? AND status = 'current';

-- Index covers WHERE clause
EXPLAIN SELECT * FROM document_versions 
WHERE document_id = '...' AND status = 'current';
-- Result: Index Scan using document_versions_document_id_idx
```

**Optimization tips:**
- Use `find_by` instead of `where(...).first` for single current version lookup
- Eager load `current_version` when listing documents: `Document.includes(:current_version)`
- Add index on `superseded_by_id` if traversing version chains frequently

### Transaction Isolation

**Default isolation is sufficient:**
```ruby
# Rails default: READ COMMITTED (PostgreSQL)
# Prevents dirty reads, ensures atomicity
ActiveRecord::Base.transaction do
  # Swap logic here
end
```

**For high-concurrency scenarios:**
```ruby
# Use SERIALIZABLE isolation to prevent phantom reads
ActiveRecord::Base.transaction(isolation: :serializable) do
  Documents::PublishVersion.call(...)
end
```

### Lock Contention

**Minimize lock duration:**
```ruby
# BAD: Long-running operations inside transaction
ActiveRecord::Base.transaction do
  new_version = create_pending_version(...)
  perform_expensive_operation()  # ❌ Holds locks
  swap_status(...)
end

# GOOD: Only critical updates in transaction
new_version = create_pending_version(...)
perform_expensive_operation()  # ✅ Outside transaction

ActiveRecord::Base.transaction do
  swap_status(new_version)
end
```

## Security Considerations

### Authorization

**Ensure user has permission to publish:**

```ruby
class Documents::PublishVersion
  def self.call(document_id:, content:, user:)
    document = Document.find(document_id)
    
    # Check authorization BEFORE transaction
    raise Pundit::NotAuthorizedError unless user.can_publish?(document)

    ActiveRecord::Base.transaction do
      # Swap logic here
    end
  end
end
```

### Audit Trail

**Track who published each version:**

```ruby
class DocumentVersion < ApplicationRecord
  belongs_to :published_by, class_name: "User", optional: true

  before_create :set_publisher

  private

  def set_publisher
    self.published_by = Current.user
  end
end
```

### Content Validation

**Sanitize user-provided content:**

```ruby
class Documents::PublishVersion
  def self.call(document_id:, content:)
    # Sanitize before storing
    sanitized_content = ActionController::Base.helpers.sanitize(
      content,
      tags: %w[p br strong em a],
      attributes: %w[href]
    )

    ActiveRecord::Base.transaction do
      # Use sanitized_content in version creation
    end
  end
end
```

## Examples

### Use Case 1: Document CMS

**Scenario:** Publishing blog posts with draft → current workflow

```ruby
# Create draft (pending status)
post = Post.create!(title: "My Post", organization: current_org)
draft = DocumentVersion.create!(
  document: post,
  status: "pending",
  content: "# Draft Content"
)

# Publish draft (pending → current)
Documents::PublishVersion.call(
  document_id: post.id,
  content: draft.content
)

# Edit and republish (current → superseded, new pending → current)
Documents::PublishVersion.call(
  document_id: post.id,
  content: "# Updated Content"
)
```

### Use Case 2: Configuration Management

**Scenario:** Feature flags with only one active configuration

```ruby
# Feature flag with current configuration
flag = FeatureFlag.create!(name: "new_ui", organization: current_org)
DocumentVersion.create!(
  document: flag,
  status: "current",
  content: { enabled: true, rollout_percentage: 50 }.to_json
)

# Update rollout (atomic swap)
Documents::PublishVersion.call(
  document_id: flag.id,
  content: { enabled: true, rollout_percentage: 100 }.to_json
)
```

### Use Case 3: Approval Workflow

**Scenario:** Only one approved proposal per project

```ruby
# Proposal pending approval
proposal = Proposal.create!(project: project)
pending = DocumentVersion.create!(
  document: proposal,
  status: "pending",
  content: "# Proposal Draft"
)

# Approve (publish as current)
if user.can_approve?(proposal)
  Documents::PublishVersion.call(
    document_id: proposal.id,
    content: pending.content
  )
end
```

## Related Patterns

- **Optimistic Locking** - Use `lock_version` column for concurrent update detection
- **Event Sourcing** - Append-only version history with state reconstitution
- **Soft Delete** - Mark versions as deleted instead of destroying
- **Temporal Tables** - Database-native time-travel queries (PostgreSQL, SQL Server)

## References

- [PostgreSQL Partial Indexes](https://www.postgresql.org/docs/current/indexes-partial.html)
- [Rails Unique Constraints](https://guides.rubyonrails.org/active_record_validations.html#uniqueness)
- [Database Transaction Isolation Levels](https://www.postgresql.org/docs/current/transaction-iso.html)
- [Rails Service Objects Pattern](https://www.toptal.com/ruby-on-rails/rails-service-objects-tutorial)
