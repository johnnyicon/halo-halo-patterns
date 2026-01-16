---
id: "pattern-ruby-rails-hotwire-streaming-openai-responses-turbo-streams"
title: "Rails Streaming OpenAI Chat with Turbo Streams"
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
  - name: hotwire
    versions: ">=1.0"
  - name: turbo
    versions: ">=7.0"
dependencies:
  - name: openai
    versions: ">=3.0"
  - name: ruby-llm
    versions: ">=0.1"
domain: hotwire
tags:
  - turbo-streams
  - streaming
  - openai
  - real-time-updates
  - background-jobs
  - websockets
introduced: 2026-01-15
last_verified: 2026-01-15
review_by: 2026-04-15
sanitized: true
related:
  - pattern-ruby-rails-actioncable-websockets
  - pattern-ruby-rails-active-job-background-processing
  - pattern-ruby-rails-hotwire-progressive-loading
---

# Rails Streaming OpenAI Chat with Turbo Streams

## Context

When building AI chat interfaces, users expect:

1. **Real-time token streaming** - See AI response appear word-by-word, not all at once
2. **Thinking indicators** - Show retrieval/processing steps before response starts
3. **No page refresh** - Updates appear via WebSocket, not HTTP polling
4. **Background execution** - Long-running AI calls don't block web server

**Problem:** OpenAI's streaming API sends tokens asynchronously, but Turbo Streams expects server-side rendering with complete HTML. How do you bridge streaming tokens to incremental DOM updates?

**Solution:** Use a background job with Turbo Streams broadcasting to accumulate tokens server-side and send complete HTML replacements for each update. This guarantees correct token order and handles network interruptions gracefully.

## Usage

### Step 1: Setup Turbo Streams Channel Subscription

**View (Turbo Stream tag):**

```erb
<%# app/views/chat/show.html.erb %>
<%= turbo_stream_from "chat_thread_#{@thread.id}" %>

<div id="messages" class="space-y-4 overflow-y-auto h-full">
  <%= render @thread.messages %>
</div>

<%= form_with url: chat_messages_path(@thread), 
              method: :post, 
              data: { turbo: true, action: "turbo:submit-end->form#reset" } do |f| %>
  <%= f.text_area :content, placeholder: "Ask a question..." %>
  <%= f.submit "Send" %>
<% end %>
```

**WebSocket connection:**
- `turbo_stream_from` subscribes to `chat_thread_#{thread.id}` channel
- All `Turbo::StreamsChannel.broadcast_*_to()` calls target this stream name
- User receives updates via ActionCable WebSocket automatically

### Step 2: Create Placeholder Message for Streaming

**Controller (optimistic UI):**

```ruby
class ChatMessagesController < ApplicationController
  def create
    @thread = current_organization.chat_threads.find(params[:thread_id])
    user_message = @thread.messages.create!(
      role: "user",
      content: params[:content]
    )

    # Create assistant message placeholder (empty content, will stream in)
    assistant_message = @thread.messages.create!(
      role: "assistant",
      content: "",  # Empty - will be populated by streaming job
      llm_provider: "openai",
      llm_model: "gpt-4o-mini"
    )

    # Enqueue background job for streaming
    StreamChatResponseJob.perform_later(
      thread_id: @thread.id,
      user_message_id: user_message.id,
      assistant_message_id: assistant_message.id
    )

    # Respond with Turbo Stream to append placeholder message
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append(
            "messages",
            partial: "chat_messages/message",
            locals: { message: assistant_message, streaming: true }
          ),
          turbo_stream.update("chat-form", partial: "chat/form", locals: { disabled: true })
        ]
      end
    end
  end
end
```

**Message partial (with streaming indicator):**

```erb
<%# app/views/chat_messages/_message.html.erb %>
<div id="message-<%= message.id %>" class="<%= message.role == 'user' ? 'bg-blue-50' : 'bg-gray-50' %> p-4 rounded">
  <div id="message-bubble-<%= message.id %>">
    
    <%# Thinking section (only for assistant, only during streaming) %>
    <% if message.role == "assistant" && local_assigns[:streaming] %>
      <details id="thinking-<%= message.id %>" open class="mb-2 text-xs text-muted-foreground">
        <summary class="cursor-pointer font-medium">Thinking...</summary>
        <div id="thinking-steps-<%= message.id %>" class="mt-1 space-y-1 pl-3 border-l-2">
          <!-- Steps will be broadcast here -->
        </div>
      </details>
    <% end %>

    <%# Message content %>
    <div id="message-content-<%= message.id %>" class="prose prose-sm">
      <%= message.content.present? ? render_markdown(message.content) : "" %>
      <% if local_assigns[:streaming] %>
        <span class="inline-block w-2 h-4 bg-primary/50 animate-pulse ml-0.5"></span>
      <% end %>
    </div>
  </div>
</div>
```

### Step 3: Implement Streaming Background Job

**Job class:**

```ruby
class StreamChatResponseJob < ApplicationJob
  queue_as :default

  # PRD: Retry with polynomial backoff for rate limits
  retry_on RubyLLM::RateLimitError, wait: :polynomially_longer, attempts: 3

  def perform(thread_id:, user_message_id:, assistant_message_id:)
    @thread = ChatThread.find(thread_id)
    @user_message = ChatMessage.find(user_message_id)
    @assistant_message = ChatMessage.find(assistant_message_id)
    @stream_name = "chat_thread_#{thread_id}"
    @full_response = ""
    @thinking_steps = []

    begin
      # 1. Get AI settings
      resolver = Ai::SettingsResolver.for(@thread.organization)
      unless resolver.embeddings_configured? && resolver.llm_configured?
        broadcast_error("AI not configured. Please add API keys in Settings.")
        return
      end

      # 2. Run retrieval (RAG context assembly)
      broadcast_thinking_step("✓ Searching knowledge base...")
      
      retrieval_result = Rag::RetrievalService.call(
        organization: @thread.organization,
        query: @user_message.content,
        top_k: 8
      )

      unless retrieval_result.success?
        broadcast_error("No documents found. Add documents to ask questions.")
        return
      end

      chunks = retrieval_result.chunks
      broadcast_thinking_step("✓ Found #{chunks.count} relevant sources")

      # 3. Assemble context
      context_text = chunks.map { |c| c.content }.join("\n\n---\n\n")
      messages = build_llm_messages(context_text)

      # 4. Stream from OpenAI
      broadcast_thinking_step("✓ Generating response...")
      stream_response(resolver, messages)

      # 5. Update assistant message with final content
      @assistant_message.update!(
        content: @full_response,
        llm_provider: resolver.settings.default_llm_provider,
        llm_model: resolver.settings.default_llm_model
      )

      # 6. Persist sources
      persist_sources(retrieval_result.rag_query)

      # 7. Collapse thinking section and show sources
      broadcast_thinking_complete
      broadcast_completion

    rescue StandardError => e
      Rails.logger.error "[StreamChatResponseJob] Failed: #{e.message}"
      broadcast_error("Chat failed: #{e.message}")
    ensure
      broadcast_form_reset
    end
  end

  private

  def build_llm_messages(context_text)
    system_prompt = <<~PROMPT
      You are a helpful assistant that answers questions based on the provided context.
      
      Instructions:
      - Answer based on the provided context only.
      - Be concise and accurate.
      - Use markdown formatting for readability (headings, lists, bold, code blocks).
      - Do NOT include source references in your response. Sources are displayed separately.
    PROMPT

    [
      { role: "system", content: system_prompt },
      { role: "user", content: "Context:\n#{context_text}\n\nQuestion: #{@user_message.content}" }
    ]
  end

  def stream_response(resolver, messages)
    chat_client = resolver.chat_client

    # CRITICAL: Use streaming API from OpenAI
    chat_client.complete_stream(messages: messages) do |token|
      @full_response << token
      broadcast_token(token)
    end
  end

  # CRITICAL: Always broadcast full accumulated content, not just the token
  # This guarantees correct token order even if WebSocket delivery is out of order
  def broadcast_token(_token)
    Turbo::StreamsChannel.broadcast_replace_to(
      @stream_name,
      target: "message-content-#{@assistant_message.id}",
      html: render_streaming_content_html
    )

    # Auto-scroll every 5 tokens
    @token_count ||= 0
    @token_count += 1
    broadcast_scroll if @token_count % 5 == 0
  end

  def render_streaming_content_html
    # Include pulsing cursor while streaming
    cursor = '<span class="inline-block w-2 h-4 bg-primary/50 animate-pulse ml-0.5"></span>'
    rendered_markdown = render_markdown(@full_response)
    
    %(<div id="message-content-#{@assistant_message.id}" class="prose prose-sm">#{rendered_markdown}#{cursor}</div>)
  end

  def broadcast_scroll
    Turbo::StreamsChannel.broadcast_action_to(
      @stream_name,
      action: "append",
      target: "scroll-trigger",
      html: '<script>document.getElementById("messages")?.scrollTo({top: document.getElementById("messages").scrollHeight, behavior: "smooth"})</script>'
    )
  end

  def broadcast_thinking_step(step_text)
    @thinking_steps << step_text
    
    steps_html = @thinking_steps.map do |s| 
      %(<div class="flex items-center gap-2"><span>#{ERB::Util.html_escape(s)}</span></div>)
    end.join

    Turbo::StreamsChannel.broadcast_replace_to(
      @stream_name,
      target: "thinking-steps-#{@assistant_message.id}",
      html: steps_html
    )
  end

  def broadcast_thinking_complete
    # Close the thinking details element
    Turbo::StreamsChannel.broadcast_replace_to(
      @stream_name,
      target: "thinking-#{@assistant_message.id}",
      html: render_thinking_complete_html
    )
  end

  def render_thinking_complete_html
    steps_html = @thinking_steps.map do |s|
      %(<div class="flex items-center gap-2"><span>#{ERB::Util.html_escape(s)}</span></div>)
    end.join

    <<~HTML
      <details id="thinking-#{@assistant_message.id}" class="mb-2 text-xs text-muted-foreground">
        <summary class="cursor-pointer font-medium">Thinking complete</summary>
        <div id="thinking-steps-#{@assistant_message.id}" class="mt-1 space-y-1 pl-3 border-l-2">
          #{steps_html}
        </div>
      </details>
    HTML
  end

  def broadcast_completion
    # 1. Replace content div without cursor (final render)
    final_content_html = %(<div id="message-content-#{@assistant_message.id}" class="prose prose-sm">#{render_markdown(@full_response)}</div>)

    Turbo::StreamsChannel.broadcast_replace_to(
      @stream_name,
      target: "message-content-#{@assistant_message.id}",
      html: final_content_html
    )

    # 2. Append sources inside message bubble
    sources_html = render_sources_html

    Turbo::StreamsChannel.broadcast_append_to(
      @stream_name,
      target: "message-bubble-#{@assistant_message.id}",
      html: sources_html
    )

    # 3. Final scroll to show sources
    broadcast_scroll
  end

  def render_sources_html
    return "" if @assistant_message.sources.empty?

    sources = @assistant_message.sources.includes(doc_chunk: :document).order(:rank)
    sources_items = sources.map do |source|
      relevance = ((1.0 - source.cosine_distance) * 100).round
      relevance_badge = %(<span class="text-green-600 font-medium">#{relevance}%</span>)
      
      <<~HTML
        <div class="p-2 bg-white rounded border space-y-1">
          <div class="flex items-center justify-between gap-2">
            <p class="font-medium">#{ERB::Util.html_escape(source.document_title)}</p>
            #{relevance_badge}
          </div>
          <p class="text-muted-foreground text-xs">"#{ERB::Util.html_escape(source.excerpt)}"</p>
        </div>
      HTML
    end.join

    <<~HTML
      <details class="mt-3 text-xs">
        <summary class="cursor-pointer text-muted-foreground hover:text-foreground">
          #{sources.count} sources used
        </summary>
        <div class="mt-2 space-y-2">
          #{sources_items}
        </div>
      </details>
    HTML
  end

  def broadcast_form_reset
    Turbo::StreamsChannel.broadcast_update_to(
      @stream_name,
      target: "chat-form",
      partial: "chat/form",
      locals: { disabled: false }
    )
  end

  def broadcast_error(message)
    error_html = <<~HTML
      <div id="message-content-#{@assistant_message.id}" class="text-sm text-red-600">
        <p>#{ERB::Util.html_escape(message)}</p>
      </div>
    HTML

    Turbo::StreamsChannel.broadcast_replace_to(
      @stream_name,
      target: "message-content-#{@assistant_message.id}",
      html: error_html
    )
  end

  def render_markdown(text)
    return "" if text.blank?

    Commonmarker.to_html(text, options: {
      extension: { strikethrough: true, table: true, autolink: true },
      render: { unsafe: false, hardbreaks: false }
    })
  end

  def persist_sources(rag_query)
    return unless rag_query

    rag_query.results.includes(:doc_chunk).ordered.each do |result|
      ChatMessageSource.create!(
        chat_message: @assistant_message,
        doc_chunk: result.doc_chunk,
        rank: result.rank,
        score: result.score,
        cosine_distance: result.cosine_distance
      )
    end
  end
end
```

### Step 4: Configure ActionCable for Production

**config/cable.yml:**

```yaml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: app_production
```

**config/environments/production.rb:**

```ruby
Rails.application.configure do
  # ActionCable mount point
  config.action_cable.url = "wss://example.com/cable"
  config.action_cable.allowed_request_origins = ['https://example.com']
end
```

### Step 5: Testing Strategy

**System test (streaming behavior):**

```ruby
require "application_system_test_case"

class ChatStreamingTest < ApplicationSystemTestCase
  driven_by :playwright  # Or :selenium_headless

  test "streams AI response in real-time" do
    thread = chat_threads(:one)
    visit chat_thread_path(thread)

    # Send message
    fill_in "content", with: "What is Ruby on Rails?"
    click_button "Send"

    # Expect thinking indicator
    assert_selector "details[id^='thinking-']", text: "Thinking..."

    # Wait for streaming to start (first token appears)
    assert_selector "span.animate-pulse", count: 1, wait: 5

    # Wait for response to complete (cursor disappears)
    assert_no_selector "span.animate-pulse", wait: 30

    # Verify final content exists
    assert_selector "div[id^='message-content-']", text: /Ruby on Rails/i

    # Verify sources displayed
    assert_selector "details", text: /sources used/i
  end

  test "displays error if AI not configured" do
    # Remove AI API key
    organization = organizations(:one)
    organization.ai_settings.update!(openai_api_key: nil)

    thread = chat_threads(:one)
    visit chat_thread_path(thread)

    fill_in "content", with: "Test question"
    click_button "Send"

    # Expect error message
    assert_selector "div.text-red-600", text: /AI not configured/i, wait: 5
  end
end
```

**Job test (token accumulation):**

```ruby
require "test_helper"

class StreamChatResponseJobTest < ActiveJob::TestCase
  test "accumulates tokens and broadcasts full content each time" do
    thread = chat_threads(:one)
    user_msg = thread.messages.create!(role: "user", content: "Test?")
    asst_msg = thread.messages.create!(role: "assistant", content: "")

    # Stub streaming API to yield tokens
    chat_client = mock()
    chat_client.expects(:complete_stream).yields("Hello").yields(" ").yields("world")
    
    resolver = mock()
    resolver.stubs(:chat_client).returns(chat_client)
    resolver.stubs(:embeddings_configured?).returns(true)
    resolver.stubs(:llm_configured?).returns(true)
    
    Ai::SettingsResolver.stubs(:for).returns(resolver)

    # Verify broadcasts contain full accumulated content
    Turbo::StreamsChannel.expects(:broadcast_replace_to).with(
      "chat_thread_#{thread.id}",
      has_entries(html: includes("Hello"))
    ).at_least_once

    Turbo::StreamsChannel.expects(:broadcast_replace_to).with(
      "chat_thread_#{thread.id}",
      has_entries(html: includes("Hello world"))
    ).at_least_once

    StreamChatResponseJob.perform_now(
      thread_id: thread.id,
      user_message_id: user_msg.id,
      assistant_message_id: asst_msg.id
    )

    # Verify final message content
    assert_equal "Hello world", asst_msg.reload.content
  end
end
```

## Tradeoffs

### Pros

- **Real-time UX** - Users see AI thinking and response streaming live
- **Background execution** - Long AI calls don't block web server threads
- **Graceful degradation** - If WebSocket drops, user sees last broadcasted state
- **Token order guarantee** - Always broadcast full accumulated content, not deltas
- **Progressive enhancement** - Works with standard Rails Turbo, no custom JS needed

### Cons

- **More data over wire** - Sending full content each token vs deltas (trade: reliability for bandwidth)
- **ActionCable dependency** - Requires WebSocket infrastructure (Redis in production)
- **Job queue dependency** - Background job system must be running (Solid Queue, Sidekiq, etc.)
- **Testing complexity** - System tests require browser with WebSocket support

### When to Use

- ✅ AI chat interfaces (customer support, internal Q&A, chatbots)
- ✅ RAG systems with streaming responses
- ✅ Long-running LLM generation (30+ seconds)
- ✅ Applications already using Hotwire/Turbo

### When NOT to Use

- ❌ Simple synchronous AI calls (<5 seconds, no streaming needed)
- ❌ Static site generation (no WebSocket support)
- ❌ API-only backends (return SSE or streaming JSON instead)
- ❌ Low-bandwidth environments (consider pagination instead)

## Verification Checklist

### ActionCable Setup
- [ ] `config/cable.yml` configured for Redis in production
- [ ] `config.action_cable.url` set in production.rb
- [ ] `turbo_stream_from` tag in view subscribes to correct stream name

### Message Placeholder
- [ ] Controller creates assistant message with empty content before job enqueue
- [ ] Turbo Stream appends placeholder message with streaming indicator (cursor)
- [ ] Thinking section (details element) present for assistant messages

### Background Job
- [ ] Job uses `Turbo::StreamsChannel.broadcast_*_to()` to send updates
- [ ] Job accumulates tokens in instance variable (`@full_response`)
- [ ] Each broadcast sends full accumulated content, not just new token
- [ ] Thinking steps broadcast to `thinking-steps-#{message.id}` target
- [ ] Final broadcast removes cursor and adds sources

### Token Streaming
- [ ] `complete_stream` API yields tokens from OpenAI (or LLM provider)
- [ ] Each token appended to `@full_response` before broadcasting
- [ ] Markdown rendering happens on each broadcast (server-side)
- [ ] Auto-scroll broadcasts every N tokens (throttled)

### Error Handling
- [ ] Job rescues StandardError and broadcasts error message
- [ ] Error messages user-friendly (not raw exception text)
- [ ] Form re-enabled after error (`broadcast_form_reset`)
- [ ] Rate limit errors trigger retry with backoff

### Testing
- [ ] System test verifies thinking indicator appears
- [ ] System test waits for cursor to disappear (streaming complete)
- [ ] System test verifies sources displayed after completion
- [ ] Job test verifies full content accumulation and broadcast

## Performance Considerations

### Broadcast Frequency

**Token-by-token broadcasting:**
```ruby
# Every single token (high overhead)
def broadcast_token(token)
  @full_response << token
  broadcast_replace_to(...)  # 100+ broadcasts per response
end
```

**Throttled broadcasting (recommended):**
```ruby
# Every 5 tokens or every 100ms (reduced overhead)
def broadcast_token(token)
  @full_response << token
  @token_count ||= 0
  @token_count += 1
  
  if @token_count % 5 == 0 || Time.current - @last_broadcast > 0.1
    broadcast_replace_to(...)
    @last_broadcast = Time.current
  end
end
```

**Trade-off:** Fewer broadcasts = less real-time feel, but lower WebSocket/Redis overhead.

### Redis Connection Pooling

**ActionCable Redis adapter:**
```yaml
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV['REDIS_URL'] %>
  channel_prefix: app_production
  # IMPORTANT: Size pool based on expected concurrent streams
  pool: 5  # Increase if many concurrent chats
```

**Monitor Redis connections:**
```bash
redis-cli INFO clients  # Check connected_clients
```

### Job Queue Tuning

**Concurrency considerations:**
```ruby
# config/initializers/solid_queue.rb (or Sidekiq config)
config.workers = 5  # Number of concurrent streaming jobs
config.queues = ["default:5", "mailers:2"]  # Prioritize chat over email
```

**Job timeout:**
```ruby
class StreamChatResponseJob < ApplicationJob
  # Set timeout to prevent hanging on slow LLM responses
  around_perform do |job, block|
    Timeout.timeout(90.seconds) do  # 90s max per streaming response
      block.call
    end
  end
end
```

## Security Considerations

### ActionCable Authentication

**Verify user has access to thread:**

```ruby
# app/channels/turbo/streams_channel.rb
module Turbo
  class StreamsChannel < Turbo::StreamsChannel
    def subscribed
      if params[:signed_stream_name]
        super
      elsif stream_name_for_thread
        # Custom verification for chat threads
        thread_id = stream_name_for_thread
        thread = current_user.organization.chat_threads.find_by(id: thread_id)
        
        if thread
          stream_from "chat_thread_#{thread.id}"
        else
          reject
        end
      else
        reject
      end
    end

    private

    def stream_name_for_thread
      # Extract thread_id from stream name "chat_thread_{id}"
      params[:channel]&.match(/chat_thread_(\d+)/)&.captures&.first
    end
  end
end
```

### Content Sanitization

**Always escape user input in broadcasts:**

```ruby
def broadcast_thinking_step(step_text)
  # Use ERB::Util.html_escape to prevent XSS
  safe_text = ERB::Util.html_escape(step_text)
  
  Turbo::StreamsChannel.broadcast_replace_to(
    @stream_name,
    html: "<div>#{safe_text}</div>"
  )
end
```

### Rate Limiting

**Prevent abuse of streaming endpoint:**

```ruby
class ChatMessagesController < ApplicationController
  # Throttle per user
  before_action :check_rate_limit, only: [:create]

  private

  def check_rate_limit
    key = "chat_rate_limit:#{current_user.id}"
    count = Rails.cache.increment(key, 1, expires_in: 1.minute) || 1
    
    if count > 10  # Max 10 messages per minute
      render json: { error: "Rate limit exceeded" }, status: :too_many_requests
    end
  end
end
```

## Examples

### Use Case 1: Customer Support Chatbot

**Scenario:** Customer asks question about product, AI streams answer with RAG retrieval

```ruby
# User sends: "How do I reset my password?"
# System:
# 1. Creates placeholder message
# 2. Enqueues StreamChatResponseJob
# 3. Job retrieves relevant docs (password reset guide)
# 4. Job streams OpenAI response token-by-token
# 5. User sees: "To reset your password: 1. Go to Settings..."
# 6. Sources displayed: "Password Reset Guide (95% relevance)"
```

### Use Case 2: Internal Knowledge Base

**Scenario:** Employee searches company wiki, sees thinking steps before answer

```ruby
# User asks: "What is our vacation policy?"
# Thinking steps shown:
# - ✓ Searching knowledge base...
# - ✓ Found 3 relevant sources
# - ✓ Generating response...
# [Streaming starts]
# Final response: "According to the employee handbook..."
# Sources: "Employee Handbook > Benefits > Vacation (88% relevance)"
```

### Use Case 3: Code Assistant

**Scenario:** Developer asks coding question, sees code blocks streaming with syntax highlighting

```ruby
# User: "How do I implement pagination in Rails?"
# Response streams with markdown code blocks:
# "Here's how to implement pagination..."
# ```ruby
# def index
#   @posts = Post.page(params[:page])
# end
# ```
# Sources: "Rails Guides > Pagination (92% relevance)"
```

## Related Patterns

- **ActionCable Authentication** - Secure WebSocket connections with user verification
- **Background Job Processing** - ActiveJob with Solid Queue, Sidekiq, or Resque
- **Server-Sent Events (SSE)** - Alternative to WebSocket for one-way streaming
- **Hotwire Turbo Frames** - Partial page updates without full page refresh

## References

- [Turbo Streams Documentation](https://turbo.hotwired.dev/handbook/streams)
- [ActionCable Overview](https://guides.rubyonrails.org/action_cable_overview.html)
- [OpenAI Streaming API](https://platform.openai.com/docs/api-reference/streaming)
- [Ruby LLM Gem](https://github.com/alexrudall/ruby-openai)
- [Background Job Best Practices](https://guides.rubyonrails.org/active_job_basics.html)
