---
id: "pattern-ruby-rails-falcon-rack-hijack-sse-streaming"
title: "Falcon SSE Streaming via rack.hijack + synchronous websocket-driver"
type: troubleshooting
status: validated
confidence: high
revision: 1
languages:
  - language: ruby
    versions: ">=3.2"
frameworks:
  - name: rails
    versions: ">=8.0"
dependencies:
  - falcon
  - websocket-driver
domain: streaming
tags:
  - falcon
  - puma
  - sse
  - rack-hijack
  - websocket-driver
  - fiber
  - streaming
  - actioncontroller-live
introduced: 2026-02-25
last_verified: 2026-02-25
review_by: 2026-05-25
sanitized: true
related:
  - pattern-ruby-rails-websocket-callback-thread-crosses-live-stream
---

# Falcon SSE Streaming via rack.hijack + synchronous websocket-driver

## Context

When you replace Puma with [Falcon](https://github.com/socketry/falcon) in a Rails 8 app, standard Rails SSE approaches silently break. Falcon is a fiber-per-request server built on the `async` gem. Its concurrency model is fundamentally incompatible with techniques that depend on threads, nested `Async` reactors, or Rails' `ActionController::Live`.

**Common scenario:** A Rails controller streams SSE to the browser while bridging to a backend daemon over WebSocket. Moving from Puma to Falcon for performance or fiber-based concurrency breaks the streaming path in at least three distinct ways.

## Symptoms

- Browser receives headers but no SSE events, then the connection closes silently
- Rails logs show a `204 No Content` response even though the controller returned `200`
- The daemon receives the WS message and processes it, but responses never reach the browser
- No exception is raised — the controller appears to complete normally
- Works fine on Puma; breaks only on Falcon

## Root Cause: Three Failed Approaches

### 1. `ActionController::Live` — thread vs. fiber conflict

```
┌────────────────────────────────────────────────┐
│  Falcon Fiber (handles request)                │
│                                                │
│  controller.process_action                     │
│    └─ ActionController::Live calls             │
│         Thread.new { ... }  ← new_controller_thread
│              │                                 │
│              │  response.stream.write(...)     │
│              │     ↑ lives on NEW THREAD       │
│                                                │
│  Falcon's fiber scheduler has no visibility    │
│  into this thread. Response is lost.           │
└────────────────────────────────────────────────┘
```

`ActionController::Live` spawns a dedicated thread (`new_controller_thread`) to own the response stream. Falcon's fiber scheduler is unaware of this thread. The actual response lifecycle is managed by the fiber, not the thread, so writes on the thread go nowhere and the fiber completes without content.

### 2. `self.response_body = StreamBody` — Rails 204 override

Setting the Rack response body to a custom object with `#each` looks like a clean alternative, but Rails' middleware stack (specifically `ActionDispatch::Executor` and body-consuming middleware) reads and discards the body during request processing, then sets it to `nil`. Falcon sees a `nil` body and sends `204 No Content`.

### 3. `async-websocket` with `Sync do` inside `rack.hijack` — nested reactor

```ruby
# ❌ This creates a nested Async reactor
env["rack.hijack"].call do |stream|
  Sync do                        # ← starts a NEW reactor
    ws = Async::WebSocket::Client.connect(endpoint)
    # Falcon is already running an Async reactor.
    # Sync { } inside a running reactor is undefined / conflicts.
    # Daemon processes the message; WS responses can't flow back.
  end
end
```

`Sync do` detects whether there is an existing `Async::Reactor`. Inside `rack.hijack`, Falcon has already started one. The nested reactor either raises or runs in a broken partial state. The outbound WS message goes out (datagrams are fire-and-forget), but reading responses from the WS socket requires the scheduler to be running cleanly — it isn't.

## Solution: `rack.hijack` + `websocket-driver` + `TCPSocket`

The working approach has three components:

1. **Partial `rack.hijack`** — take ownership of the raw socket for SSE, bypassing Rails' response lifecycle entirely.
2. **`websocket-driver`** — a protocol-only WS library with no I/O opinions. You own the read loop.
3. **`TCPSocket` + `IO.select`** — plain synchronous I/O that runs correctly on any fiber, thread, or coroutine.

All I/O stays on the **calling fiber**. No reactors, no background threads.

### Controller: SSE via `rack.hijack`

```ruby
class StreamController < ApplicationController
  # No ActionController::Live include — we bypass Rails streaming entirely

  def events
    # Tell Rack we want to hijack the socket after headers are sent
    response.headers["Content-Type"]  = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"
    response.headers["rack.hijack"]   = true

    # Falcon calls this proc in the current fiber after flushing headers
    env["rack.hijack"] = proc do |stream|
      begin
        bridge = DaemonBridge.new
        bridge.call(params[:message], stream: stream) do |event_type, data|
          stream.write("event: #{event_type}\n")
          stream.write("data: #{data.to_json}\n\n")
          stream.flush
        end
      ensure
        stream.close rescue nil
      end
    end

    # Return a no-content response — rack.hijack takes over from here
    head :ok
  end
end
```

**Why this works:** `rack.hijack` gives you a raw `IO`-like object representing the client socket. Falcon calls the proc in the same fiber that handles the request — no thread crossing, no scheduler conflict. You write raw HTTP chunks directly. Rails' response lifecycle never touches the body.

### Bridge: outbound WS via `websocket-driver` + `TCPSocket`

```ruby
require "websocket/driver"
require "socket"

class DaemonBridge
  DAEMON_HOST = "localhost"
  DAEMON_PORT = 3001
  HANDSHAKE_TIMEOUT = 5   # seconds
  READ_TIMEOUT      = 120 # seconds

  def call(content, stream:, &block)
    # 1. Open a plain TCP socket — no Async, no EventMachine
    tcp = TCPSocket.new(DAEMON_HOST, DAEMON_PORT)

    # 2. Build a websocket-driver client — it handles framing only
    driver = WebSocket::Driver.client(DriverIO.new(tcp))

    # 3. Wire up protocol callbacks
    opened = false
    driver.on(:open)    { opened = true }
    driver.on(:message) { |e| dispatch(e.data, &block) }
    driver.on(:error)   { |e| raise "WS error: #{e.message}" }
    driver.on(:close)   { tcp.close rescue nil }

    # 4. Start the handshake — driver.start writes the HTTP upgrade request
    driver.start

    # 5. Synchronous read loop — runs on the calling fiber, no reactor needed
    deadline = Time.now + HANDSHAKE_TIMEOUT
    until opened
      raise "WS handshake timeout" if Time.now > deadline
      pump(tcp, driver)
    end

    # 6. Send the message
    driver.text(build_message(content).to_json)

    # 7. Drain responses until the server closes the WS
    loop do
      ready = IO.select([tcp], nil, nil, READ_TIMEOUT)
      raise "WS read timeout" unless ready
      break unless pump(tcp, driver)
    end
  ensure
    tcp&.close rescue nil
  end

  private

  # Read available bytes and feed them to the driver's parser
  def pump(tcp, driver)
    data = tcp.readpartial(4096)
    driver.parse(data)
    true
  rescue EOFError, Errno::ECONNRESET
    false
  end

  def dispatch(raw, &block)
    parsed = JSON.parse(raw)
    # Translate daemon payload → [event_type, data] and yield
    event_type = parsed.fetch("type", "message")
    yield(event_type, parsed)
  rescue JSON::ParseError => e
    yield("error", { message: "parse error: #{e.message}" })
  end

  def build_message(content)
    { type: "chat", content: content }
  end

  # Thin IO adapter: websocket-driver calls #write to send bytes
  class DriverIO
    def initialize(tcp)
      @tcp = tcp
    end

    def write(data)
      @tcp.write(data)
    end

    # websocket-driver uses the URL from this method for the handshake
    def url
      "ws://#{DaemonBridge::DAEMON_HOST}:#{DaemonBridge::DAEMON_PORT}/ws"
    end
  end
end
```

**Why `websocket-driver`:** The gem is a pure protocol state machine. It reads bytes you feed it (`driver.parse`) and writes bytes you read from it (via `DriverIO#write`). There is no I/O thread, no reactor, no event loop of its own. You control when and how bytes move — here with `TCPSocket.readpartial` + `IO.select`, which is synchronous and fiber-friendly.

## Architectural Comparison

| Approach | Puma | Falcon | Why |
|---|---|---|---|
| `ActionController::Live` | ✅ | ❌ | Spawns `new_controller_thread` — invisible to Falcon's fiber scheduler |
| `response_body = StreamBody` | ✅ | ❌ | Middleware consumes and nils the body; Falcon sends 204 |
| `async-websocket` + `Sync do` inside hijack | ✅ | ❌ | Nested `Async::Reactor` inside an already-running reactor |
| `rack.hijack` + `websocket-driver` + `TCPSocket` | ✅ | ✅ | Synchronous I/O on the calling fiber; no scheduler assumptions |

## Prevention

- **On Falcon, never use `ActionController::Live`.** Its threading model is fundamentally incompatible. Use `rack.hijack` instead.
- **Never call `Sync do` inside a `rack.hijack` proc on Falcon.** You are already inside a managed fiber. Use synchronous I/O directly.
- **Prefer `websocket-driver` over EventMachine-based or `async-websocket` gems** when you need an outbound WS connection inside `rack.hijack` — it has no I/O opinions and works in any execution context.
- **Test SSE streaming explicitly when switching servers.** A successful response (no exception, correct status code) does not guarantee the stream body was delivered.

## References

- [Falcon gem (socketry/falcon)](https://github.com/socketry/falcon)
- [websocket-driver gem](https://github.com/faye/websocket-driver-ruby)
- [Rack spec: rack.hijack](https://github.com/rack/rack/blob/main/SPEC.rdoc#label-Hijacking)
- [ActionController::Live source (Rails)](https://github.com/rails/rails/blob/main/actionpack/lib/action_controller/metal/live.rb)
- [Async gem (socketry/async)](https://github.com/socketry/async)
