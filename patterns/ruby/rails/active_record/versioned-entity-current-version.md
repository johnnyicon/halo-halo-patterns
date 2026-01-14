---
id: "pattern-ruby-rails-versioned-entity"
title: "Versioned Entity with Current Version Pattern"
type: implementation
status: draft
confidence: high
revision: 1
languages:
  - ruby
frameworks:
  - rails
dependencies: []
domain: active_record
tags:
  - activerecord
  - versioning
  - history
  - database-design
  - associations
  - current-pointer
introduced: 2026-01-13
last_verified: 2026-01-13
review_by: 2026-04-13
sanitized: true
related: []
---

# Versioned Entity with Current Version Pattern

## Summary
Data modeling pattern for entities that require version history, using a main entity table linked to a separate versions table with a current version pointer.

## Context
Building applications where content changes over time and you need to track version history, restore previous versions, and maintain performance for current version access.

## Problem
- Need to track complete history of content changes
- Current version should be fast to access
- Version comparison and restoration should be possible
- Storage should be efficient without complex diff algorithms
- Queries for current content should remain simple

## Solution

### Main Entity Model
```ruby
# app/models/canvas_document.rb
class CanvasDocument < ApplicationRecord
  belongs_to :organization
  belongs_to :chat_thread, optional: true
  
  has_many :versions, 
           class_name: 'CanvasDocumentVersion', 
           dependent: :destroy
  
  has_one :current_version, 
          -> { where(current: true) }, 
          class_name: 'CanvasDocumentVersion'

  validates :title, presence: true
  validates :status, inclusion: { in: %w[active archived] }

  scope :active, -> { where(status: 'active') }
  scope :recent, -> { order(updated_at: :desc) }

  # Convenience methods for current content
  delegate :body_markdown, :word_count, :version_number, 
           to: :current_version, allow_nil: true

  def preview_text(length: 100)
    return "Empty document" unless current_version&.body_markdown.present?
    
    # Strip markdown and truncate
    plain_text = current_version.body_markdown
                                .gsub(/[#*`_\[\](){}~>+-]/, '')
                                .strip
    plain_text.truncate(length)
  end

  # Version management
  def create_version!(content:, author: nil)
    ActiveRecord::Base.transaction do
      # Mark current version as not current
      versions.update_all(current: false)
      
      # Create new current version
      versions.create!(
        body_markdown: content,
        version_number: next_version_number,
        current: true,
        author: author,
        word_count: count_words(content)
      )
    end
  end

  def revert_to_version!(version_id)
    version = versions.find(version_id)
    create_version!(
      content: version.body_markdown,
      author: nil # System action
    )
  end

  private

  def next_version_number
    (versions.maximum(:version_number) || 0) + 1
  end

  def count_words(text)
    text.to_s.split(/\s+/).length
  end
end
```

### Version Model
```ruby
# app/models/canvas_document_version.rb
class CanvasDocumentVersion < ApplicationRecord
  belongs_to :canvas_document
  
  validates :body_markdown, presence: true
  validates :version_number, presence: true, uniqueness: { scope: :canvas_document_id }
  validates :current, uniqueness: { scope: :canvas_document_id, message: "Only one current version allowed" }, if: :current?

  scope :ordered, -> { order(:version_number) }
  scope :recent, -> { order(created_at: :desc) }

  # Display helpers
  def display_label
    case version_number
    when 1
      "Initial version"
    else
      "Version #{version_number}"
    end
  end

  def changes_summary(previous_version = nil)
    return "Initial version" unless previous_version
    
    # Simple change detection
    word_diff = word_count - previous_version.word_count
    case word_diff
    when 0
      "Minor edits"
    when 1..20
      "+#{word_diff} words"
    when -20..-1
      "#{word_diff} words"
    else
      word_diff > 0 ? "Major additions" : "Major deletions"
    end
  end

  # Content comparison
  def diff_with(other_version)
    # Basic implementation - could be enhanced with proper diff library
    {
      lines_added: count_new_lines(other_version),
      lines_removed: count_removed_lines(other_version),
      similar: similarity_percentage(other_version)
    }
  end

  private

  def count_new_lines(other_version)
    self_lines = body_markdown.lines.map(&:strip)
    other_lines = other_version.body_markdown.lines.map(&:strip)
    (self_lines - other_lines).length
  end

  def count_removed_lines(other_version)
    other_version.count_new_lines(self)
  end

  def similarity_percentage(other_version)
    # Simple character-based similarity
    common = (body_markdown.chars & other_version.body_markdown.chars).length
    total = [body_markdown.length, other_version.body_markdown.length].max
    return 100 if total == 0
    
    (common.to_f / total * 100).round
  end
end
```

### Database Schema
```ruby
# db/migrate/create_canvas_documents.rb
class CreateCanvasDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :canvas_documents, id: :uuid do |t|
      t.string :title, null: false
      t.string :status, default: 'active'
      t.string :visibility, default: 'private'
      t.json :metadata, default: {}
      
      t.references :organization, null: false, foreign_key: true, type: :uuid
      t.references :chat_thread, null: true, foreign_key: true, type: :uuid
      
      t.timestamps
    end

    add_index :canvas_documents, [:organization_id, :status]
    add_index :canvas_documents, :created_at
  end
end

# db/migrate/create_canvas_document_versions.rb
class CreateCanvasDocumentVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :canvas_document_versions, id: :uuid do |t|
      t.references :canvas_document, null: false, foreign_key: true, type: :uuid
      
      t.text :body_markdown, null: false
      t.integer :version_number, null: false
      t.boolean :current, default: false
      t.integer :word_count, default: 0
      t.string :author # For future user tracking
      
      t.timestamps
    end

    add_index :canvas_document_versions, [:canvas_document_id, :version_number], unique: true
    add_index :canvas_document_versions, [:canvas_document_id, :current], unique: true, where: "current = true"
    add_index :canvas_document_versions, :created_at
  end
end
```

### Service Integration
```ruby
# app/services/canvas_documents/update_service.rb
class CanvasDocuments::UpdateService < ApplicationService
  def initialize(document:, body_markdown:, title: nil, expected_version: nil)
    @document = document
    @body_markdown = body_markdown
    @title = title
    @expected_version = expected_version
  end

  def call
    ActiveRecord::Base.transaction do
      # Version conflict detection
      if version_conflict?
        return failure(["Document was modified by another user. Please refresh and try again."])
      end

      # Update document metadata
      @document.update!(title: @title) if @title.present?

      # Create new version with content
      version = @document.create_version!(
        content: @body_markdown,
        author: current_user&.id
      )

      # Touch document to update timestamp
      @document.touch

      success(
        document: @document.reload,
        version: version
      )
    end
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  end

  private

  def version_conflict?
    return false unless @expected_version

    current_number = @document.current_version&.version_number
    current_number != @expected_version
  end
end
```

### Query Patterns
```ruby
# Efficient queries for common operations

# Get documents with current content
documents = CanvasDocument.includes(:current_version)
                         .where(organization: current_org)

# Get recent versions for a document  
recent_versions = document.versions
                         .recent
                         .limit(10)
                         .includes(:canvas_document)

# Search current content
searchable_documents = CanvasDocument.joins(:current_version)
                                   .where("canvas_document_versions.body_markdown ILIKE ?", "%#{query}%")

# Version comparison
document = CanvasDocument.find(id)
current = document.current_version
previous = document.versions.where("version_number < ?", current.version_number)
                           .order(version_number: :desc)
                           .first
```

## Benefits
- **Performance**: Current version access is fast with proper indexing
- **Simplicity**: No complex diff algorithms or merge conflicts  
- **Auditability**: Complete history of all changes
- **Flexibility**: Easy to add metadata, authorship, branching later
- **Data Integrity**: Referential integrity maintained with foreign keys

## When to Use
- ✅ Document editing systems
- ✅ Content management with approval workflows  
- ✅ Any data that changes over time and needs history
- ✅ Systems where users need to restore previous versions

## When NOT to Use
- ❌ Data that never needs version history
- ❌ High-frequency updates (analytics, counters)
- ❌ Binary or very large content (consider blob storage)
- ❌ Real-time collaborative editing (needs operational transforms)

## Trade-offs
**Pros:**
- Simple to understand and implement
- Fast current version access
- Complete change history
- Easy to add features (authorship, comments, etc.)

**Cons:**
- Storage grows linearly with versions
- No built-in diff capabilities
- Can't handle concurrent edits without conflicts
- Version table can get large for active documents

## Implementation Variations

### With Soft Deletes
```ruby
class CanvasDocument < ApplicationRecord
  scope :active, -> { where(deleted_at: nil) }
  
  def archive!
    update!(status: 'archived', deleted_at: Time.current)
  end
end
```

### With Change Descriptions
```ruby
class CanvasDocumentVersion < ApplicationRecord
  validates :change_description, presence: true, unless: -> { version_number == 1 }
  
  def self.create_with_description!(document, content, description)
    document.create_version!(
      content: content,
      change_description: description
    )
  end
end
```

### With Branching Support
```ruby
class CanvasDocumentVersion < ApplicationRecord
  belongs_to :parent_version, class_name: 'CanvasDocumentVersion', optional: true
  has_many :child_versions, class_name: 'CanvasDocumentVersion', foreign_key: 'parent_version_id'
  
  scope :main_branch, -> { where(parent_version: nil) }
end
```

## Related Patterns
- Event Sourcing (more complex alternative)
- Copy-on-Write
- Temporal Database Patterns
- Audit Log Pattern

## Performance Considerations
- Index `(document_id, current)` for fast current version lookup
- Consider archiving old versions after N days/versions
- Use database constraints to ensure data integrity
- Monitor version table growth and plan accordingly

## Tags
`versioning` `data-modeling` `rails` `activerecord` `content-management` `audit-trail`

---
**Pattern ID**: versioned-entity-current-version-pattern  
**Created**: 2026-01-13  
**Language**: Ruby/Rails  
**Complexity**: Medium  
**Maturity**: Stable