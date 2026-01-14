---
id: "pattern-ruby-rails-service-result"
title: "Rails Service Object with Result Pattern"
type: implementation
status: draft
confidence: high
revision: 1
languages:
  - ruby
frameworks:
  - rails
dependencies: []
domain: services
tags:
  - service-objects
  - result-pattern
  - error-handling
  - architecture
  - transaction-safety
introduced: 2026-01-13
last_verified: 2026-01-13
review_by: 2026-04-13
sanitized: true
related: []
---

# Rails Service Object with Result Pattern

## Summary
Consistent service layer architecture that returns structured success/failure results with clear error handling and data encapsulation.

## Context
Building service objects that need to return both success/failure states and associated data or errors, while maintaining clean interfaces and predictable error handling across a Rails application.

## Problem
- Service objects often have inconsistent return patterns (nil, boolean, exceptions)
- Error handling is scattered and unpredictable
- Callers need to check multiple conditions to understand service outcome
- Mixed concerns between business logic and result communication

## Solution

### Result Object Pattern
```ruby
class ServiceResult
  attr_reader :success, :errors, :data

  def initialize(success:, errors: [], data: {})
    @success = success
    @errors = Array(errors)
    @data = data
  end

  def success?
    @success
  end

  def failure?
    !@success
  end

  # Convenience access to specific data
  def method_missing(method, *args)
    if @data.key?(method)
      @data[method]
    else
      super
    end
  end

  def respond_to_missing?(method, include_private = false)
    @data.key?(method) || super
  end
end
```

### Service Base Class
```ruby
class ApplicationService
  def self.call(*args, **kwargs)
    new(*args, **kwargs).call
  end

  private

  def success(data = {})
    ServiceResult.new(success: true, data: data)
  end

  def failure(errors)
    ServiceResult.new(success: false, errors: errors)
  end
end
```

### Implementation Example
```ruby
class CanvasDocuments::CreateService < ApplicationService
  def initialize(organization:, title: nil, initial_content: "", **options)
    @organization = organization
    @title = title || "Untitled Document"
    @initial_content = initial_content
    @options = options
  end

  def call
    ActiveRecord::Base.transaction do
      document = create_document
      version = create_initial_version(document)
      
      success(
        document: document,
        version: version
      )
    end
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  rescue StandardError => e
    Rails.logger.error "Document creation failed: #{e.message}"
    failure(["Document creation failed"])
  end

  private

  def create_document
    @organization.canvas_documents.create!(
      title: @title,
      status: @options[:status] || "active",
      visibility: @options[:visibility] || "private",
      chat_thread: @options[:chat_thread],
      metadata: @options[:metadata] || {}
    )
  end

  def create_initial_version(document)
    document.versions.create!(
      body_markdown: @initial_content,
      version_number: 1,
      current: true
    )
  end
end
```

### Usage Pattern
```ruby
# In controllers
result = CanvasDocuments::CreateService.call(
  organization: current_organization,
  title: params[:title],
  initial_content: params[:content]
)

if result.success?
  render json: { document: result.document, version: result.version }
else
  render json: { errors: result.errors }, status: :unprocessable_entity
end

# In other services
def some_business_logic
  result = CanvasDocuments::CreateService.call(params)
  return failure(result.errors) unless result.success?
  
  # Continue with result.document
  process_document(result.document)
end
```

## Benefits
- **Consistent Interface**: All services return the same result structure
- **Explicit Error Handling**: Errors are part of the interface, not exceptions
- **Data Access**: Clean access to returned data via method calls
- **Composability**: Services can easily call other services and chain results
- **Testability**: Easy to test success/failure scenarios

## When to Use
- ✅ Complex business operations that can fail
- ✅ Operations that return multiple pieces of data
- ✅ Service composition (services calling other services)
- ✅ When you need consistent error handling across your app

## When NOT to Use
- ❌ Simple CRUD operations that Rails handles well
- ❌ Operations where exceptions are the appropriate error handling
- ❌ Very simple services with single return values

## Trade-offs
**Pros:**
- Predictable, consistent interface
- Clear separation of concerns
- Easy error propagation in service chains
- Self-documenting success/failure states

**Cons:**
- More verbose than simple return values
- Requires discipline to maintain consistency
- Can be overkill for simple operations

## Related Patterns
- Command Pattern
- Railway Programming
- Monads (Functional Programming)

## Implementation Notes
- Consider using a gem like `dry-monads` for more advanced result handling
- Add logging within services for debugging complex flows
- Use consistent error message formatting across services
- Consider adding result types for different success scenarios

## Tags
`rails` `service-object` `error-handling` `architecture` `result-pattern`

---
**Pattern ID**: rails-service-result-pattern  
**Created**: 2026-01-13  
**Language**: Ruby/Rails  
**Complexity**: Medium  
**Maturity**: Stable