---
id: "pattern-ruby-rails-active-storage-multi-file-upload-background"
title: "Rails Multi-File Upload with Active Storage and Background Processing"
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
  - name: active_storage
    versions: ">=7.0"
dependencies:
  - name: solid_queue
    versions: ">=0.1"
    note: "Or any ActiveJob adapter (Sidekiq, Resque, etc.)"
domain: active_storage
tags:
  - file-upload
  - background-jobs
  - direct-upload
  - async-processing
  - content-extraction
introduced: 2026-01-15
last_verified: 2026-01-15
review_by: 2026-04-15
sanitized: true
related:
  - pattern-ruby-rails-active-record-document-status-swap-with-unique-constraint
---

# Rails Multi-File Upload with Active Storage and Background Processing

## Context

When building applications that require users to upload multiple files (documents, images, datasets), you need:
- **Client-side direct uploads** to avoid tying up application servers
- **Background job processing** to extract content, transform files, or index data
- **Validation** of file types, sizes, and batch constraints
- **Progress tracking** to show users real-time status updates
- **Error handling** for encoding issues, extraction failures, and API rate limits

This pattern provides a complete implementation for multi-file uploads with:
- Rails ActiveStorage DirectUpload for efficient client-side uploads
- Background job pipeline for content extraction and processing
- Real-time status updates via Turbo Streams
- Robust error handling and retry logic
- Telemetry and timing tracking

## When to Use This Pattern

**Use this pattern when:**
- Uploading multiple files (images, documents, datasets) from a single form/interface
- Files require post-upload processing (text extraction, image transformation, indexing)
- File processing is CPU/IO intensive and should not block web requests
- Users need real-time feedback on upload and processing status
- File constraints (size, type, count) must be validated before acceptance

**When NOT to use:**
- Single-file uploads with no post-processing (use standard ActiveStorage)
- Synchronous file handling is acceptable (small files, fast processing)
- No client-side validation or progress tracking needed

## Usage

### Step 1: Configure ActiveStorage with CORS for DirectUpload

Create `config/initializers/active_storage.rb` to enable cross-origin direct uploads:

```ruby
# frozen_string_literal: true

# ActiveStorage DirectUpload CORS configuration
# Required for client-side direct uploads to work properly

Rails.application.config.after_initialize do
  ActiveStorage::DirectUploadsController.class_eval do
    skip_before_action :verify_authenticity_token, only: [:create]

    before_action :set_cors_headers

    private

    def set_cors_headers
      headers["Access-Control-Allow-Origin"] = request.origin || "*"
      headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
      headers["Access-Control-Allow-Headers"] = "Content-Type, Accept"
      headers["Access-Control-Allow-Credentials"] = "true"
    end
  end
end
```

**Why:** Rails DirectUpload API requires CORS headers to accept client-side uploads. Without this, browsers will reject the upload requests with CORS errors.

---

### Step 2: Add ActiveStorage Attachment to Model

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  # ActiveStorage attachment for uploaded file
  has_one_attached :source_file

  # Validation for file presence
  validates :source_file, attached: true, on: :create

  # Custom validation for file type
  validate :acceptable_file_type

  private

  def acceptable_file_type
    return unless source_file.attached?

    acceptable_types = %w[text/plain text/markdown text/html text/csv]
    unless acceptable_types.include?(source_file.content_type)
      errors.add(:source_file, "must be a text, markdown, HTML, or CSV file")
    end
  end
end
```

**Storage configuration:** Ensure `config/storage.yml` and `config/environments/*.rb` are configured for your storage backend (local, S3, Azure, GCS).

---

### Step 3: Create Upload Controller with Batch Validation

```ruby
# app/controllers/documents/uploads_controller.rb
module Documents
  class UploadsController < ApplicationController
    # Maximum constraints
    MAX_FILES_PER_BATCH = 100
    MAX_FILE_SIZE = 1.gigabyte
    MAX_BATCH_SIZE = 10.gigabytes
    ALLOWED_TYPES = %w[.md .markdown .txt .html .csv].freeze

    def create
      validate_batch!
      
      results = []
      errors = []

      params[:documents].each do |doc_params|
        result = create_document(doc_params)
        if result[:success]
          results << result[:document]
        else
          errors << result[:error]
        end
      end

      if errors.any?
        render json: { errors: errors, created: results.size }, status: :unprocessable_entity
      else
        render json: { documents: results.map(&:as_json) }, status: :created
      end
    end

    private

    def validate_batch!
      # Check file count
      if params[:documents].size > MAX_FILES_PER_BATCH
        raise ValidationError, "Cannot upload more than #{MAX_FILES_PER_BATCH} files at once"
      end

      # Calculate total batch size
      total_size = params[:documents].sum do |doc|
        blob = ActiveStorage::Blob.find_signed(doc[:signed_blob_id])
        blob.byte_size
      end

      if total_size > MAX_BATCH_SIZE
        raise ValidationError, "Total batch size cannot exceed #{MAX_BATCH_SIZE / 1.gigabyte} GB"
      end
    end

    def create_document(doc_params)
      # Find the blob from DirectUpload
      blob = ActiveStorage::Blob.find_signed(doc_params[:signed_blob_id])

      # Validate individual file size
      if blob.byte_size > MAX_FILE_SIZE
        return { success: false, error: "File #{blob.filename} exceeds 1 GB limit" }
      end

      # Validate file type by extension
      extension = File.extname(blob.filename.to_s).downcase
      unless ALLOWED_TYPES.include?(extension)
        return { success: false, error: "File type #{extension} not supported" }
      end

      # Create document record
      document = current_organization.documents.create!(
        title: doc_params[:title] || blob.filename.to_s,
        status: "pending",
        metadata: {
          ingest_status: "queued",
          uploaded_at: Time.current.iso8601
        }
      )

      # Attach the uploaded file
      document.source_file.attach(blob)

      # Enqueue background job for processing
      DocumentProcessingJob.perform_later(document.id)

      { success: true, document: document }
    rescue StandardError => e
      { success: false, error: "Failed to create document: #{e.message}" }
    end

    class ValidationError < StandardError; end
  end
end
```

**Key validations:**
- **File count:** Max 100 files per batch
- **File size:** Each file ≤ 1 GB
- **Batch size:** Total ≤ 10 GB
- **File type:** Extension-based whitelist (`.md`, `.txt`, `.html`, `.csv`)

---

### Step 4: Create Content Extraction Service

```ruby
# app/services/documents/extract_content.rb
module Documents
  class ExtractContent
    def self.call(blob)
      new(blob).call
    end

    def initialize(blob)
      @blob = blob
    end

    def call
      content = extract_content
      encoding = detect_encoding(content)
      { content: content, encoding: encoding }
    end

    private

    def extract_content
      case File.extname(@blob.filename.to_s).downcase
      when '.md', '.markdown', '.txt'
        # Plain text: read as UTF-8
        @blob.download.force_encoding('UTF-8')
      when '.html'
        # HTML: extract text content, strip tags
        require 'nokogiri'
        Nokogiri::HTML(@blob.download).text
      when '.csv'
        # CSV: convert to JSON or text table
        require 'csv'
        CSV.parse(@blob.download, headers: true).map(&:to_h).to_json
      else
        raise "Unsupported file type: #{File.extname(@blob.filename.to_s)}"
      end
    rescue StandardError => e
      raise "Content extraction failed: #{e.message}"
    end

    def detect_encoding(content)
      # Ensure content is valid UTF-8, replace invalid bytes
      content.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace)
      content.encoding.name
    end
  end
end
```

**Encoding handling:**
- Force UTF-8 encoding for text files
- Replace invalid/undefined byte sequences
- Extract text from HTML using Nokogiri
- Convert CSV to JSON for structured storage

---

### Step 5: Create Background Processing Job

```ruby
# app/jobs/document_processing_job.rb
class DocumentProcessingJob < ApplicationJob
  queue_as :default

  # Retry on rate limits with polynomial backoff
  retry_on Faraday::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  # Generic retry for transient errors
  retry_on StandardError, wait: ->(executions) { 2**executions }, attempts: 5

  def perform(document_id)
    document = Document.find(document_id)

    # Validate source file exists
    unless document.source_file.attached?
      document.update!(
        status: "failed",
        metadata: document.metadata.merge(
          "ingest_status" => "failed",
          "error" => "Missing source file"
        )
      )
      broadcast_status(document, "failed")
      raise "Missing source file for document #{document_id}"
    end

    # Track timing for each stage
    timings = {}

    # Stage 1: Extract content
    started_extract = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    update_status(document, "extracting")
    
    extracted = Documents::ExtractContent.call(document.source_file.blob)
    timings["extract_ms"] = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_extract) * 1000).to_i

    # Stage 2: Save extracted content
    document.update!(
      content: extracted[:content],
      metadata: document.metadata.merge(
        "encoding" => extracted[:encoding],
        "content_length" => extracted[:content].bytesize
      )
    )

    # Stage 3: Additional processing (indexing, embedding, etc.)
    started_processing = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    update_status(document, "processing")
    
    # Example: Index content, generate embeddings, etc.
    # IndexingService.call(document: document)
    
    timings["processing_ms"] = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_processing) * 1000).to_i

    # Mark as completed
    document.update!(
      status: "completed",
      metadata: document.metadata.merge(
        "ingest_status" => "completed",
        "ingest_timings" => timings,
        "completed_at" => Time.current.iso8601
      )
    )
    broadcast_status(document, "completed")

  rescue StandardError => e
    # Mark as failed and store error
    document.update!(
      status: "failed",
      metadata: document.metadata.merge(
        "ingest_status" => "failed",
        "error" => e.message,
        "error_backtrace" => e.backtrace.first(5)
      )
    )
    broadcast_status(document, "failed")
    raise # Re-raise for job retry logic
  end

  private

  def update_status(document, status)
    document.update!(
      metadata: document.metadata.merge("ingest_status" => status)
    )
    broadcast_status(document, status)
  end

  def broadcast_status(document, status)
    # Broadcast via Turbo Streams for real-time UI updates
    Turbo::StreamsChannel.broadcast_replace_to(
      "documents_org_#{document.organization_id}",
      target: "document-#{document.id}-status",
      partial: "documents/status_badge",
      locals: { document: document, status: status }
    )
  end
end
```

**Key features:**
- **Stage tracking:** Extract → Process → Complete
- **Timing telemetry:** Store milliseconds for each stage
- **Error handling:** Capture errors, update status, re-raise for retries
- **Real-time updates:** Broadcast status via Turbo Streams
- **Retry logic:** Polynomial backoff for rate limits, exponential for other errors

---

### Step 6: Add Real-Time Status Updates (Turbo Streams)

In your view, subscribe to the Turbo Streams channel:

```erb
<%# app/views/documents/index.html.erb %>
<%= turbo_stream_from "documents_org_#{current_organization.id}" %>

<div id="documents-list">
  <%= render @documents %>
</div>
```

Status badge partial:

```erb
<%# app/views/documents/_status_badge.html.erb %>
<span id="document-<%= document.id %>-status" class="status-badge <%= status %>">
  <%= status.titleize %>
</span>
```

**How it works:**
- Jobs broadcast updates to `documents_org_#{org_id}` channel
- View subscribes via `turbo_stream_from` helper
- Status badge auto-updates without page refresh

---

## Tradeoffs

### Pros
- **Non-blocking uploads:** DirectUpload offloads file transfer from application server
- **Efficient batch handling:** Process multiple files without overwhelming server
- **Real-time feedback:** Users see progress as files are processed
- **Resilient:** Automatic retries for transient failures and rate limits
- **Telemetry:** Track timings and costs for each stage
- **Scalable:** Background jobs can be distributed across workers

### Cons
- **Complexity:** Requires background job infrastructure (Solid Queue, Sidekiq, etc.)
- **Storage costs:** ActiveStorage stores files in configured backend (S3, etc.)
- **CORS configuration:** Requires proper CORS setup for DirectUpload
- **Client-side JS:** Needs JavaScript for DirectUpload API
- **Error handling:** Must handle partial batch failures gracefully

---

## Verification Checklist

### Functional
- [ ] Upload single file succeeds, triggers background job
- [ ] Upload multiple files (10+) succeeds, all jobs enqueued
- [ ] Files validate against type/size constraints
- [ ] Batch size limit enforced (reject >10 GB batches)
- [ ] File count limit enforced (reject >100 files)
- [ ] Invalid file types rejected with error message

### Content Extraction
- [ ] Text files (.txt, .md) extract correctly
- [ ] HTML files strip tags, preserve text
- [ ] CSV files convert to JSON structure
- [ ] Non-UTF-8 files handle encoding fallback
- [ ] Empty files rejected or handled gracefully

### Background Processing
- [ ] Job extracts content successfully
- [ ] Job updates status: queued → extracting → processing → completed
- [ ] Failed jobs retry with exponential backoff
- [ ] Rate-limited jobs retry with polynomial backoff
- [ ] Job stores timing telemetry in metadata

### Real-Time Updates
- [ ] Status badge updates without page refresh
- [ ] Multiple users see updates simultaneously
- [ ] Failed uploads show error messages
- [ ] Progress tracked per document in UI

### Error Handling
- [ ] Missing source file triggers failure status
- [ ] Extraction errors logged and surfaced to user
- [ ] API rate limits trigger job retry
- [ ] Transient errors retry up to 5 times
- [ ] Permanent failures marked as failed, no infinite retries

---

## Performance Considerations

**Upload performance:**
- DirectUpload bypasses Rails server, uploads directly to storage backend
- Use CDN or edge locations for faster uploads (e.g., S3 Transfer Acceleration)

**Job queue:**
- Process files in parallel across multiple workers
- Use dedicated queue for file processing to isolate from other jobs
- Monitor queue depth to detect bottlenecks

**Content extraction:**
- Large files (>100 MB) may timeout; consider streaming extraction
- CSV parsing can be memory-intensive; use `CSV.foreach` for large files
- HTML parsing with Nokogiri is fast but can be CPU-heavy for complex documents

**Database writes:**
- Use `update_columns` to bypass callbacks if not needed
- Batch writes for multiple files to reduce database round-trips

---

## Security Considerations

**File validation:**
- **Extension-based validation is not secure** — use content-type detection (e.g., `marcel` gem)
- Scan for malicious content (virus scanning, malware detection)
- Limit file sizes to prevent disk exhaustion

**CORS configuration:**
- Restrict `Access-Control-Allow-Origin` to known domains in production
- Never use wildcard `*` in production environments

**Direct upload signed URLs:**
- Signed blob IDs expire after 5 minutes by default
- Do not log or expose signed_blob_id values

**Content extraction:**
- Sanitize HTML content to prevent XSS attacks
- Be cautious with CSV injection attacks (formulas in CSV cells)

---

## Example Use Cases

1. **Document management system:** Users upload multiple PDFs, Word docs for indexing
2. **RAG/AI applications:** Upload source documents for embedding and retrieval
3. **Dataset import:** Users upload CSV files for analysis or reporting
4. **Media library:** Upload images, videos for processing (resize, transcode)
5. **Knowledge base:** Upload markdown documentation for search/indexing

---

## Related Patterns

- **pattern-ruby-rails-active-record-document-status-swap-with-unique-constraint:** Use for managing document version states (pending → current → superseded)
- **pattern-ruby-rails-hotwire-turbo-streams:** Real-time UI updates via Turbo Streams
- **pattern-ruby-rails-active-job-retry-strategies:** Advanced retry logic for background jobs

---

## References

- [Rails ActiveStorage Guide](https://edgeguides.rubyonrails.org/active_storage_overview.html)
- [DirectUpload JavaScript API](https://edgeguides.rubyonrails.org/active_storage_overview.html#direct-uploads)
- [ActiveJob Retry Strategies](https://edgeguides.rubyonrails.org/active_job_basics.html#retrying-or-discarding-failed-jobs)
- [Turbo Streams Reference](https://turbo.hotwired.dev/handbook/streams)
