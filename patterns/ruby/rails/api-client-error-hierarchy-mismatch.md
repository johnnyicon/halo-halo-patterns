---
id: "pattern-ruby-rails-api-client-error-hierarchy-mismatch"
title: "API Client Error Hierarchy Mismatch in ActiveJob Retry Logic"
type: troubleshooting
status: validated
confidence: high
revision: 1
languages:
  - language: ruby
    versions: ">=3.0"
frameworks:
  - name: rails
    versions: ">=7.0 <9.0"
dependencies:
  - name: activejob
    versions: ">=7.0"
runtime: []
domain: background_jobs
tags:
  - activejob
  - retry
  - error-handling
  - api-client
  - rate-limit
  - 429
  - faraday
introduced: 2026-01-10
last_verified: 2026-01-10
review_by: 2026-04-10
maintainers: []
deprecated_date: null
superseded_by: null
related:
  - "pattern-ruby-rails-background-jobs-worker-not-running"
sanitized: true
migration_note: null
notes: "Pattern applies to any gem that wraps HTTP clients (OpenAI, Anthropic, Stripe, etc.) where the underlying HTTP client raises different exceptions than the gem's public API"
---

# API Client Error Hierarchy Mismatch in ActiveJob Retry Logic

## Context

Background jobs calling external APIs (OpenAI, Stripe, etc.) fail permanently on rate limit errors (429) despite configuring retry logic, because the job's `retry_on` declaration only catches the gem's custom error class but the underlying HTTP client raises a different exception class.

**Affected versions:** Rails 7.0+ with ActiveJob, any HTTP client library (Faraday, HTTParty, etc.), any gem that abstracts HTTP calls

**Common scenario:** 
- Developer configures `retry_on CustomGem::RateLimitError`
- Underlying HTTP client raises `Faraday::TooManyRequestsError`
- Error hierarchy mismatch causes job to fail permanently without retrying

**Architecture:** This occurs in layered architectures where:
1. Application layer (ActiveJob) expects gem-specific errors
2. Gem layer (e.g., `ruby_llm`, `stripe-ruby`) may or may not re-raise HTTP errors
3. HTTP client layer (Faraday, Net::HTTP) raises transport-level errors

## Symptoms

- Jobs fail with rate limit errors (429) despite retry configuration
- Error logs show HTTP client exceptions: `Faraday::TooManyRequestsError`, `HTTParty::ResponseError`, `Net::HTTPTooManyRequests`
- Jobs exhaust retries immediately or fail on first attempt
- Other errors from same gem are retried successfully (confirming retry logic works)
- Rate limit recovery requires manual job re-enqueue

**Diagnostic pattern:**
```ruby
# Job configuration (appears correct)
retry_on CustomGem::RateLimitError, wait: :polynomially_longer

# But logs show:
# [Job] FAILED: Faraday::TooManyRequestsError (429 Too Many Requests)
# [Job] retries_exhausted
```

## Root Cause

**Error hierarchy mismatch** between:
1. **Application expectation:** Gem's public error class (`CustomGem::RateLimitError`)
2. **Runtime reality:** HTTP client's error class (`Faraday::TooManyRequestsError`)

**Why this happens:**
- Gems may not wrap or re-raise all HTTP client errors
- HTTP client raises transport-level exceptions before gem layer can catch them
- Network errors, timeouts, and HTTP status errors may bypass gem's error handling
- Gem configuration may affect whether errors are re-raised or wrapped

**Compounding factor:** 
429 responses can mean different things:
- **Rate limit** (temporary) → Should retry with backoff
- **Quota exhaustion** (account limit) → Should fail fast with clear error

Both return same HTTP status code, requiring inspection of response body to distinguish.

## Fix

### Step 1: Add HTTP Client Error to Retry Logic

**Identify the actual exception class:**
```ruby
# Check job failure logs for exact exception class
# Example: Faraday::TooManyRequestsError, HTTParty::ResponseError, etc.
```

**Add explicit retry for HTTP client errors:**
```ruby
class DocumentIngestJob < ApplicationJob
  # Catch both gem's error AND underlying HTTP client error
  retry_on CustomGem::RateLimitError, wait: :polynomially_longer, attempts: 10
  retry_on Faraday::TooManyRequestsError, wait: :polynomially_longer, attempts: 10
  
  # Add other HTTP errors if needed
  retry_on Faraday::ServerError, wait: :polynomially_longer, attempts: 5

  def perform(document_id)
    # API call via gem
    CustomGem.api_call(document_id)
  end
end
```

### Step 2: Configure Dual-Layer Retry

**Application layer (ActiveJob):**
- Use polynomial backoff for gradual spacing
- Set reasonable attempt limits (10-15 for rate limits)

**Client layer (Gem/HTTP):**
- Enable gem's built-in retry if available
- Configure conservative retry counts to stay within ActiveJob retry budget

**Example configuration:**
```ruby
# config/initializers/custom_gem.rb
CustomGem.configure do |config|
  config.retry_interval = 1.0   # Start with 1 second
  config.max_retries = 5        # Client-level retries
  config.timeout = 30           # Prevent hanging
end
```

**Total retry budget calculation:**
```
Total attempts = (ActiveJob attempts) × (Gem retries + 1)
Example: 10 × (5 + 1) = 60 total API calls maximum
```

### Step 3: Add Instrumentation

**Log errors with context:**
```ruby
class DocumentIngestJob < ApplicationJob
  retry_on Faraday::TooManyRequestsError, wait: :polynomially_longer do |job, error|
    Rails.logger.warn(
      "Rate limit hit: #{error.class} - " \
      "Job: #{job.class.name}, " \
      "Attempts: #{job.executions}, " \
      "Args: #{job.arguments.inspect}"
    )
  end

  def perform(document_id)
    CustomGem.api_call(document_id)
  rescue Faraday::TooManyRequestsError => e
    # Log full response for diagnostics
    Rails.logger.error("429 Response Body: #{e.response[:body]}")
    raise # Re-raise to trigger ActiveJob retry
  end
end
```

### Step 4: Distinguish Rate Limits from Quota Exhaustion

**Inspect response body to determine retry strategy:**
```ruby
def perform(document_id)
  CustomGem.api_call(document_id)
rescue Faraday::TooManyRequestsError => e
  response_body = JSON.parse(e.response[:body]) rescue {}
  error_code = response_body.dig("error", "code")
  
  if error_code == "insufficient_quota"
    # Quota exhaustion - fail fast with clear message
    raise QuotaExhaustedError, "API quota exceeded. Check billing."
  else
    # True rate limit - let retry logic handle it
    raise
  end
end
```

## Verification Checklist

**Before deploying:**
- [ ] Identify exact exception class from logs (don't guess)
- [ ] Add explicit `retry_on` for HTTP client exception
- [ ] Configure gem-level retries (if supported)
- [ ] Calculate total retry budget (job retries × client retries)
- [ ] Add logging to track retry behavior
- [ ] Test with actual rate limit (use low quota or rate limit testing endpoint)

**After deploying:**
- [ ] Monitor job retry patterns in logs
- [ ] Verify jobs recover from 429s automatically
- [ ] Check total retry counts don't exceed expectations
- [ ] Confirm quota errors fail fast with clear messages
- [ ] Validate backoff timing (not too aggressive or slow)

**Test scenarios:**
1. Trigger actual 429 rate limit → Should retry and eventually succeed
2. Trigger quota exhaustion → Should fail fast with quota error
3. Trigger other API errors → Should use appropriate retry strategy
4. Verify retry intervals follow backoff curve (exponential or polynomial)

## Tradeoffs

**Benefits:**
- ✅ Automatic recovery from transient rate limits
- ✅ Reduced operational burden (no manual re-queuing)
- ✅ Graceful degradation under API pressure
- ✅ Better error visibility with instrumentation

**Costs:**
- ⚠️ Increased job execution time during rate limit events
- ⚠️ Higher database load from retry polling (SolidQueue, Sidekiq)
- ⚠️ Potential for retry storms if misconfigured
- ⚠️ Complexity of dual-layer retry configuration

**When NOT to use:**
- Time-sensitive jobs that must complete within strict SLA
- Jobs where retry attempts consume billable resources
- APIs without clear retry-after headers or rate limit documentation
- High-frequency jobs where retry storms could cascade

**Alternatives:**
- Circuit breaker pattern (fail fast after threshold)
- Rate limiter middleware (prevent 429s proactively)
- Dedicated slow queue for rate-limited operations
- Manual retry queue with admin interface

## References

**ActiveJob Retry Documentation:**
- https://edgeguides.rubyonrails.org/active_job_basics.html#retrying-or-discarding-failed-jobs

**HTTP Client Error Hierarchies:**
- Faraday: `Faraday::ClientError` → `Faraday::TooManyRequestsError`
- HTTParty: `HTTParty::ResponseError`
- Net::HTTP: `Net::HTTPTooManyRequests`

**Rate Limit Best Practices:**
- RFC 6585 (429 Status Code): https://tools.ietf.org/html/rfc6585#section-4
- OpenAI Rate Limit Guide: https://platform.openai.com/docs/guides/rate-limits
- Stripe Retry Guide: https://stripe.com/docs/error-handling#retries

**Related Patterns:**
- Exponential backoff: https://en.wikipedia.org/wiki/Exponential_backoff
- Circuit breaker: https://martinfowler.com/bliki/CircuitBreaker.html
