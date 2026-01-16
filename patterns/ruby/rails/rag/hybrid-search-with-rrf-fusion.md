---
id: "pattern-ruby-rails-rag-hybrid-search-rrf-fusion"
title: "Rails Hybrid RAG Search with RRF Fusion"
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
dependencies:
  - name: neighbor
    versions: ">=0.3"
  - name: pg
    versions: ">=1.0"
domain: rag
tags:
  - rag
  - hybrid-search
  - vector-search
  - keyword-search
  - rrf-fusion
  - pgvector
  - full-text-search
introduced: 2026-01-15
last_verified: 2026-01-15
review_by: 2026-04-15
sanitized: true
related:
  - pattern-ruby-rails-pgvector-nearest-neighbors
  - pattern-ruby-rails-postgres-full-text-search
  - pattern-ruby-rails-rag-chunking-strategy
---

# Rails Hybrid RAG Search with RRF Fusion

## Context

When building Retrieval-Augmented Generation (RAG) systems, a single retrieval method often misses relevant documents:

**Problem scenarios:**
- **Vector-only search:** Misses exact keyword matches (e.g., user asks about "PostgreSQL 14", but similar docs about "PostgreSQL 13" rank higher)
- **Keyword-only search:** Misses semantically similar content (e.g., "reset password" vs "forgot credentials")
- **Either-or approach:** Loses recall when one method would have caught a relevant document the other missed

**Solution:** Hybrid retrieval combines both keyword and vector search, then fuses results using Reciprocal Rank Fusion (RRF). This balances precision (exact matches) with recall (semantic matches).

**When to use:**
- RAG systems requiring both semantic and exact-match capabilities
- Knowledge base search where users mix semantic queries ("how do I...") with specific terms ("API key")
- Document retrieval where both concepts and terminology matter

## Usage

### Step 1: Setup Database Schema with Indexes

**Migration (chunks table with vector embeddings):**

```ruby
class CreateDocumentChunks < ActiveRecord::Migration[7.0]
  def change
    # Ensure pgvector extension
    enable_extension "vector"

    create_table :document_chunks, id: :uuid do |t|
      t.uuid :document_id, null: false
      t.uuid :organization_id, null: false
      t.text :content, null: false
      t.vector :embedding, limit: 1536  # OpenAI ada-002 dimensions
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_foreign_key :document_chunks, :documents
    add_foreign_key :document_chunks, :organizations

    # CRITICAL: Vector index for cosine similarity search
    # HNSW is faster than IVFFlat for most workloads
    add_index :document_chunks, :embedding, 
              using: :hnsw, 
              opclass: :vector_cosine_ops

    # CRITICAL: Full-text search index for keyword retrieval
    execute <<~SQL
      CREATE INDEX index_document_chunks_on_content_tsvector 
      ON document_chunks 
      USING GIN (to_tsvector('english', content));
    SQL

    # Organization scope for multi-tenancy
    add_index :document_chunks, :organization_id
    add_index :document_chunks, :document_id
  end
end
```

**Why these indexes?**
- **HNSW (Hierarchical Navigable Small World):** Fast approximate nearest neighbor search, better than IVFFlat for < 1M vectors
- **GIN on tsvector:** Efficient full-text search with Postgres built-in stemming and stop-word handling

### Step 2: Create Query Trace Models

**RagQuery model (audit trail):**

```ruby
class RagQuery < ApplicationRecord
  belongs_to :organization
  has_many :results, class_name: "RagQueryResult", dependent: :destroy

  validates :query_text, presence: true
  validates :retrieval_config, presence: true

  # Default config from research
  DEFAULT_CONFIG = {
    top_k: 10,                # Final result count
    vector_candidate_k: 30,   # Vector search candidates
    keyword_candidate_k: 30,  # Keyword search candidates
    rrf_k: 60,                # RRF constant (balances recall vs precision)
    max_distance: 0.75        # Cosine distance threshold (0.75 = 25% min similarity)
  }.freeze

  before_validation :set_defaults, on: :create

  private

  def set_defaults
    self.retrieval_config ||= DEFAULT_CONFIG.stringify_keys
  end
end
```

**RagQueryResult model (individual result):**

```ruby
class RagQueryResult < ApplicationRecord
  belongs_to :rag_query
  belongs_to :doc_chunk, class_name: "DocumentChunk"

  validates :rank, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :score, presence: true, numericality: true
  validates :source, presence: true, inclusion: { in: %w[rrf vector keyword] }
  validates :details, presence: true

  scope :ordered, -> { order(:rank) }

  # Relevance percentage for UI display
  def relevance_percentage
    distance = details&.dig("cosine_distance")
    return nil unless distance

    ((1.0 - distance) * 100).round
  end

  # Delegate to chunk for convenience
  delegate :content, :document, :section_path, to: :doc_chunk
end
```

### Step 3: Implement Hybrid Retrieval Service

**Service class with RRF fusion:**

```ruby
module Rag
  class RetrievalService
    Result = Struct.new(:rag_query, :chunks, :timings_ms, :error, keyword_init: true) do
      def success?
        error.nil?
      end
    end

    attr_reader :organization, :query, :config

    # Research-backed defaults (k=60 from RRF literature)
    DEFAULT_TOP_K = 10
    DEFAULT_VECTOR_K = 30
    DEFAULT_KEYWORD_K = 30
    DEFAULT_RRF_K = 60
    DEFAULT_MAX_DISTANCE = 0.75  # Cosine distance threshold

    def initialize(organization:, query:, top_k: nil, vector_k: nil, keyword_k: nil, rrf_k: nil, max_distance: nil)
      @organization = organization
      @query = query.to_s.strip
      @config = {
        top_k: top_k || DEFAULT_TOP_K,
        vector_candidate_k: vector_k || DEFAULT_VECTOR_K,
        keyword_candidate_k: keyword_k || DEFAULT_KEYWORD_K,
        rrf_k: rrf_k || DEFAULT_RRF_K,
        max_distance: max_distance || DEFAULT_MAX_DISTANCE
      }
      @chunk_distances = {}  # Track distances for filtering
    end

    def self.call(...)
      new(...).call
    end

    def call
      return Result.new(error: "Query cannot be blank") if query.blank?

      # Get embeddings client
      resolver = Ai::SettingsResolver.for(organization)
      unless resolver.embeddings_configured?
        return Result.new(error: "Embeddings not configured")
      end

      # Time each phase for observability
      monotonic = Process::CLOCK_MONOTONIC
      
      # 1. Embed query
      embed_start = Process.clock_gettime(monotonic)
      query_embedding = resolver.embeddings_client.embed_one(query)
      embed_ms = ((Process.clock_gettime(monotonic) - embed_start) * 1000).round

      # 2. Base query (org-scoped)
      base_query = DocumentChunk.where(organization_id: organization.id)

      # 3. Parallel retrieval (keyword + vector)
      keyword_start = Process.clock_gettime(monotonic)
      keyword_results = retrieve_keyword_candidates(base_query)
      keyword_ms = ((Process.clock_gettime(monotonic) - keyword_start) * 1000).round

      vector_start = Process.clock_gettime(monotonic)
      vector_results = retrieve_vector_candidates(base_query, query_embedding)
      vector_ms = ((Process.clock_gettime(monotonic) - vector_start) * 1000).round

      # 4. Fusion with RRF
      rrf_start = Process.clock_gettime(monotonic)
      fused_results = reciprocal_rank_fusion(keyword_results, vector_results)
      rrf_ms = ((Process.clock_gettime(monotonic) - rrf_start) * 1000).round

      # 5. Filter by max distance (remove semantically distant chunks)
      filtered_results = fused_results.select do |r|
        distance = @chunk_distances[r[:chunk_id]]
        distance.nil? || distance <= config[:max_distance]
      end

      # 6. Take top_k
      top_results = filtered_results.first(config[:top_k])

      # 7. Persist query trace
      rag_query = persist_query_trace(top_results)

      # 8. Load full chunk records in rank order
      chunk_ids = top_results.map { |r| r[:chunk_id] }
      chunks_by_id = DocumentChunk.where(id: chunk_ids)
                                   .includes(:document)
                                   .index_by(&:id)
      ordered_chunks = chunk_ids.map { |id| chunks_by_id[id] }.compact

      Result.new(
        rag_query: rag_query,
        chunks: ordered_chunks,
        timings_ms: {
          embed_query: embed_ms,
          keyword_retrieval: keyword_ms,
          vector_retrieval: vector_ms,
          rrf_fusion: rrf_ms
        }
      )
    rescue => e
      Rails.logger.error "[RAG] Retrieval failed: #{e.message}"
      Result.new(error: "Retrieval failed: #{e.message}")
    end

    private

    def retrieve_keyword_candidates(base_query)
      # Postgres full-text search with stemming
      base_query
        .where("to_tsvector('english', content) @@ plainto_tsquery('english', ?)", query)
        .limit(config[:keyword_candidate_k])
        .pluck(:id)
        .each_with_index
        .map { |id, idx| { chunk_id: id, rank: idx + 1 } }
    end

    def retrieve_vector_candidates(base_query, query_embedding)
      # pgvector cosine similarity (neighbor gem)
      chunks = base_query
        .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
        .limit(config[:vector_candidate_k])

      # Store distances for filtering
      chunks.each do |chunk|
        @chunk_distances[chunk.id] = chunk.neighbor_distance
      end

      chunks.each_with_index.map { |chunk, idx| { chunk_id: chunk.id, rank: idx + 1 } }
    end

    # Reciprocal Rank Fusion (RRF)
    # Formula: score = sum(1 / (k + rank_i)) for each list i
    # Higher k → more emphasis on top results
    def reciprocal_rank_fusion(keyword_results, vector_results)
      rrf_k = config[:rrf_k]
      scores = Hash.new(0.0)
      ranks = Hash.new { |h, k| h[k] = {} }

      # Add keyword scores
      keyword_results.each do |r|
        scores[r[:chunk_id]] += 1.0 / (rrf_k + r[:rank])
        ranks[r[:chunk_id]][:keyword_rank] = r[:rank]
      end

      # Add vector scores
      vector_results.each do |r|
        scores[r[:chunk_id]] += 1.0 / (rrf_k + r[:rank])
        ranks[r[:chunk_id]][:vector_rank] = r[:rank]
      end

      # Sort by fused score (descending)
      scores
        .map do |chunk_id, score|
          {
            chunk_id: chunk_id,
            score: score,
            distance: @chunk_distances[chunk_id],
            **ranks[chunk_id]
          }
        end
        .sort_by { |r| -r[:score] }
    end

    def persist_query_trace(top_results)
      rag_query = RagQuery.create!(
        organization: organization,
        query_text: query,
        retrieval_config: config.stringify_keys
      )

      top_results.each_with_index do |result, idx|
        rag_query.results.create!(
          doc_chunk_id: result[:chunk_id],
          rank: idx + 1,
          score: result[:score],
          source: "rrf",
          details: {
            vector_rank: result[:vector_rank],
            keyword_rank: result[:keyword_rank],
            cosine_distance: result[:distance],
            rrf_k: config[:rrf_k]
          }
        )
      end

      rag_query
    end
  end
end
```

### Step 4: Model Configuration for Vector Search

**DocumentChunk model:**

```ruby
class DocumentChunk < ApplicationRecord
  belongs_to :document
  belongs_to :organization

  # neighbor gem for pgvector integration
  has_neighbors :embedding

  validates :content, presence: true
  validates :embedding, presence: true

  # Full-text search scope
  scope :full_text_search, ->(query) {
    where("to_tsvector('english', content) @@ plainto_tsquery('english', ?)", query)
  }

  # Section path from metadata (for UI display)
  def section_path
    metadata&.dig("section_path") || []
  end
end
```

### Step 5: Testing Hybrid Retrieval

**Service test (with mocked embeddings):**

```ruby
require "test_helper"

class Rag::RetrievalServiceTest < ActiveSupport::TestCase
  test "fuses keyword and vector results with RRF" do
    org = organizations(:one)
    doc = documents(:one)

    # Create chunks with content for keyword matching
    chunk1 = DocumentChunk.create!(
      organization: org,
      document: doc,
      content: "PostgreSQL 14 has improved performance",
      embedding: [0.1] * 1536  # Stub vector
    )

    chunk2 = DocumentChunk.create!(
      organization: org,
      document: doc,
      content: "Database optimization techniques",
      embedding: [0.2] * 1536
    )

    # Mock embeddings client
    embeddings_client = mock()
    embeddings_client.stubs(:embed_one).returns([0.1] * 1536)
    embeddings_client.stubs(:model).returns("text-embedding-ada-002")
    embeddings_client.stubs(:dimensions).returns(1536)

    resolver = mock()
    resolver.stubs(:embeddings_configured?).returns(true)
    resolver.stubs(:embeddings_client).returns(embeddings_client)
    
    Ai::SettingsResolver.stubs(:for).returns(resolver)

    # Execute retrieval
    result = Rag::RetrievalService.call(
      organization: org,
      query: "PostgreSQL performance"
    )

    assert result.success?
    assert result.chunks.present?
    
    # Verify query trace persisted
    assert result.rag_query.persisted?
    assert result.rag_query.results.count > 0
    
    # Verify RRF source
    assert result.rag_query.results.all? { |r| r.source == "rrf" }
    
    # Verify details include both ranks
    first_result = result.rag_query.results.ordered.first
    assert first_result.details.key?("vector_rank")
    assert first_result.details.key?("keyword_rank")
    assert_equal 60, first_result.details["rrf_k"]
  end

  test "filters results by max cosine distance threshold" do
    org = organizations(:one)
    doc = documents(:one)

    # Create chunk with high distance (semantically distant)
    distant_chunk = DocumentChunk.create!(
      organization: org,
      document: doc,
      content: "Unrelated content about weather",
      embedding: [0.9] * 1536  # Very different vector
    )

    # Mock: Return high distance for this chunk
    embeddings_client = mock()
    embeddings_client.stubs(:embed_one).returns([0.1] * 1536)
    embeddings_client.stubs(:model).returns("text-embedding-ada-002")
    embeddings_client.stubs(:dimensions).returns(1536)

    resolver = mock()
    resolver.stubs(:embeddings_configured?).returns(true)
    resolver.stubs(:embeddings_client).returns(embeddings_client)
    
    Ai::SettingsResolver.stubs(:for).returns(resolver)

    # Execute with strict threshold
    result = Rag::RetrievalService.call(
      organization: org,
      query: "PostgreSQL",
      max_distance: 0.3  # Only 70%+ similarity allowed
    )

    assert result.success?
    
    # Distant chunk should be filtered out
    refute result.chunks.include?(distant_chunk)
  end
end
```

## Tradeoffs

### Pros

- **Balanced recall:** Catches both exact keyword matches AND semantically similar content
- **Robust to query phrasing:** Works whether user types technical terms or natural language
- **Research-backed:** RRF is proven to outperform single-method retrieval in RAG benchmarks
- **Explainable:** Query trace shows which chunks matched via keyword vs vector
- **Tunable:** Adjust `rrf_k`, candidate counts, and distance threshold based on domain

### Cons

- **More database queries:** Two retrieval passes (keyword + vector) vs one
- **Higher latency:** Embedding generation + two index scans + fusion logic
- **Index overhead:** Requires both GIN (FTS) and HNSW (vector) indexes on same table
- **Tuning complexity:** Multiple hyperparameters to optimize (`rrf_k`, candidate counts, threshold)

### When to Use

- ✅ RAG systems with mixed query types (semantic + exact match)
- ✅ Knowledge bases where terminology matters (technical docs, medical, legal)
- ✅ Document search with both concepts and specific entities
- ✅ Production RAG with audit trail requirements

### When NOT to Use

- ❌ Simple semantic search only (vector-only is simpler)
- ❌ Exact-match-only search (keyword-only is faster)
- ❌ Real-time constraints (<100ms latency required)
- ❌ Databases without pgvector support

## Verification Checklist

### Database Setup
- [ ] pgvector extension enabled
- [ ] HNSW index on embedding column with cosine_ops
- [ ] GIN index on tsvector for full-text search
- [ ] Organization scope index for multi-tenancy

### Models
- [ ] DocumentChunk has `has_neighbors :embedding`
- [ ] RagQuery validates retrieval_config presence
- [ ] RagQueryResult validates source in ['rrf', 'vector', 'keyword']
- [ ] Details JSONB stores vector_rank, keyword_rank, rrf_k

### Retrieval Service
- [ ] Embed query before retrieval
- [ ] Keyword retrieval uses `plainto_tsquery`
- [ ] Vector retrieval uses `nearest_neighbors` with cosine distance
- [ ] RRF fusion formula: `1 / (k + rank)` summed across lists
- [ ] Results filtered by max_distance threshold
- [ ] Query trace persisted with timings

### Testing
- [ ] Test keyword-only matches (exact terms)
- [ ] Test vector-only matches (semantic similarity)
- [ ] Test hybrid fusion (combines both)
- [ ] Test distance filtering (removes low-relevance chunks)
- [ ] Test query trace persistence (audit trail)

### Performance
- [ ] Candidate counts tuned for domain (default: 30 each)
- [ ] RRF k tuned for precision/recall balance (default: 60)
- [ ] Distance threshold calibrated to domain (default: 0.75)
- [ ] Indexes analyzed after bulk inserts (`ANALYZE document_chunks`)

## Performance Considerations

### Index Maintenance

**HNSW index build time:**
```sql
-- Concurrent build to avoid locking table
CREATE INDEX CONCURRENTLY index_document_chunks_on_embedding
ON document_chunks USING hnsw (embedding vector_cosine_ops);

-- After bulk inserts, analyze for query planner
ANALYZE document_chunks;
```

**GIN index refresh:**
```sql
-- FTS index automatically updates, but analyze after bulk inserts
ANALYZE document_chunks;
```

### Query Performance

**Candidate count trade-offs:**
```ruby
# High recall, higher latency
vector_k: 50, keyword_k: 50  # ~100-200ms

# Balanced (recommended)
vector_k: 30, keyword_k: 30  # ~50-100ms

# Fast, lower recall
vector_k: 20, keyword_k: 20  # ~30-50ms
```

**Latency breakdown (typical):**
- Embedding generation: 100-300ms (OpenAI API)
- Keyword retrieval: 10-30ms (Postgres FTS)
- Vector retrieval: 20-50ms (HNSW index)
- RRF fusion: <5ms (in-memory computation)

### Optimization Tips

**1. Parallel candidate retrieval:**
```ruby
# Use load_async for concurrent database queries
keyword_future = base_query.full_text_search(query)
                           .limit(30)
                           .load_async

vector_future = base_query.nearest_neighbors(:embedding, query_embedding)
                          .limit(30)
                          .load_async

keyword_results = keyword_future.to_a
vector_results = vector_future.to_a
```

**2. Cache embeddings for common queries:**
```ruby
def embed_query_with_cache(query)
  cache_key = "embedding:#{Digest::SHA256.hexdigest(query)}"
  
  Rails.cache.fetch(cache_key, expires_in: 1.hour) do
    embeddings_client.embed_one(query)
  end
end
```

**3. Adjust HNSW parameters for build vs search trade-off:**
```sql
-- Build index with higher ef_construction for better quality
SET hnsw.ef_construction = 200;
CREATE INDEX ... USING hnsw ...;

-- Search with lower ef for faster queries
SET hnsw.ef_search = 40;
```

## Security Considerations

### Multi-Tenancy Isolation

**Always scope queries by organization:**

```ruby
def build_base_query
  DocumentChunk.where(organization_id: organization.id)
end
```

**Index with organization for performance:**
```ruby
add_index :document_chunks, [:organization_id, :id]
```

### Query Injection Prevention

**Use parameterized queries:**

```ruby
# ✅ SAFE: Parameterized
where("to_tsvector('english', content) @@ plainto_tsquery('english', ?)", query)

# ❌ UNSAFE: String interpolation
where("to_tsvector('english', content) @@ plainto_tsquery('english', '#{query}')")
```

### Audit Trail

**Query traces enable:**
- Security audits (who searched for what)
- Performance debugging (which queries are slow)
- Relevance tuning (A/B test different configs)

```ruby
# Query all searches by user
RagQuery.where(user_id: current_user.id).order(created_at: :desc)

# Find queries that returned no results
RagQuery.left_joins(:results).where(rag_query_results: { id: nil })
```

## Examples

### Use Case 1: Technical Documentation Search

**Scenario:** User searches for "PostgreSQL connection pooling"

```ruby
result = Rag::RetrievalService.call(
  organization: org,
  query: "PostgreSQL connection pooling"
)

# Results (hybrid fusion):
# 1. Chunk with "PostgreSQL connection pooling" (exact match via keyword)
# 2. Chunk about "database connection management" (semantic via vector)
# 3. Chunk mentioning "pg pool" (partial keyword + semantic)
```

### Use Case 2: Customer Support Knowledge Base

**Scenario:** Customer asks "How do I cancel my subscription?"

```ruby
result = Rag::RetrievalService.call(
  organization: org,
  query: "How do I cancel my subscription?",
  top_k: 5
)

# Results show:
# - Exact matches: "cancel subscription" (keyword)
# - Semantic matches: "terminate account", "end membership" (vector)
# - RRF fusion ranks exact matches higher, but includes semantic alternatives
```

### Use Case 3: Legal Document Search

**Scenario:** Lawyer searches for "force majeure clause"

```ruby
result = Rag::RetrievalService.call(
  organization: law_firm,
  query: "force majeure clause",
  rrf_k: 60  # Standard balancing
)

# Keyword retrieval catches exact legal term
# Vector retrieval catches related concepts: "act of God", "unforeseen circumstances"
# RRF ensures exact term gets highest rank
```

## Related Patterns

- **pgvector Nearest Neighbors** - Vector similarity search setup
- **Postgres Full-Text Search** - Keyword search with stemming
- **RAG Chunking Strategy** - How to split documents for optimal retrieval
- **Query Rewriting** - Transform user queries before retrieval
- **Reranking** - Post-processing step after RRF (Cohere, Cross-Encoder)

## References

- [RRF Paper: "Reciprocal Rank Fusion outperforms Condorcet and individual rank learning methods"](https://plg.uwaterloo.ca/~gvcormac/cormacksigir09-rrf.pdf)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [neighbor gem](https://github.com/ankane/neighbor)
- [Postgres Full-Text Search](https://www.postgresql.org/docs/current/textsearch.html)
- [HNSW Algorithm](https://arxiv.org/abs/1603.09320)
