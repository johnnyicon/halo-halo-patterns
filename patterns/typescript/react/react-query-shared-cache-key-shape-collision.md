---
id: "react-query-shared-cache-key-shape-collision"
title: "React Query Shared Cache Key with Incompatible Return Shapes Causes Runtime Crash"
type: troubleshooting
status: validated
confidence: high
revision: 1

languages:
  - language: typescript
    versions: ">=4.5"

frameworks:
  - ecosystem: npm
    name: "@tanstack/react-query"
    version: ">=5"

dependencies:
  - ecosystem: npm
    name: react
    version: ">=18"

runtime: ["Browser"]
domain: state-management
tags:
  - react-query
  - tanstack-query
  - cache-collision
  - shared-state
  - runtime-crash
  - stale-cache
  - data-shape-mismatch

introduced: 2026-03-13
last_verified: 2026-03-13
review_by: 2026-09-13

maintainers: ["@kanekoa"]
deprecated_date: null
superseded_by: null
related:
  - "ts-nextjs-stale-ui-after-mutation"
sanitized: true
migration_note: null
notes: "Discovered in Gomanan UI. Two components on different routes shared queryKey ['daemons'] but returned incompatible shapes. Took multiple debugging rounds to identify because the code looked correct in isolation."
---

# React Query Shared Cache Key with Incompatible Return Shapes Causes Runtime Crash

## Context

React Query (TanStack Query) caches data globally by `queryKey`. When two components in different parts of the app use the same `queryKey` but their `queryFn` functions return different shapes, whichever component fetches first writes its shape to the cache. The second component reads the cached value and crashes because it expects a different shape.

This is especially insidious because:
- Each component works perfectly in isolation
- TypeScript generics (`useQuery<T>`) only enforce types at compile time — the runtime value comes from the cache, not the generic parameter
- HMR/hot reload does NOT clear the React Query in-memory cache, so fixing the queryFn doesn't help until the browser is hard-refreshed
- React error boundaries (especially class components) hold `hasError: true` state that HMR cannot reset

## Symptoms

- `TypeError: X.map is not a function` where `X` is the destructured `data` from `useQuery`
- Error occurs in Component B after Component A on a different page has already fetched
- The queryFn looks correct — it returns the right type
- Hard refresh fixes it temporarily, but navigating between pages re-triggers
- The bug appears intermittent — depends on which page loads first
- Tests pass because each component is tested in isolation without a shared cache

## Root Cause

```
Component A (Dashboard):
  useQuery({ queryKey: ['items'], queryFn: () => api.get('/items') })
  // Caches: { items: [...], total: 5 }  ← raw API response (object)

Component B (Detail Page):
  useQuery({ queryKey: ['items'], queryFn: async () => {
    const data = await api.get('/items')
    return data.items  // ← unwraps to array
  }})
  // Reads cache: { items: [...], total: 5 }  ← gets the OBJECT, not array
  // data.map() → TypeError: data.map is not a function
```

React Query serves cached data **immediately** (before refetching), so the component renders with the stale shape before the new queryFn has a chance to run.

Additionally, fixing the queryFn via HMR doesn't help because:
1. The React Query cache is in-memory JavaScript state — HMR updates modules but not runtime state
2. Class-based error boundaries hold `hasError: true` in component state — HMR cannot reset this
3. The cached data from before the fix is served to the component on next render

## Fix

### Option 1: Normalize at consumption (defensive, recommended)

Handle both possible shapes where the data is consumed:

```typescript
function ItemList() {
  const { data: raw, isLoading } = useQuery({
    queryKey: ['items'],
    queryFn: () => api.get('/api/v1/items'),
  })

  // Handles: array (unwrapped), object with .items, or undefined
  const items: Item[] = Array.isArray(raw) ? raw : (raw?.items ?? [])

  // Safe to call items.map(...) regardless of cache state
}
```

### Option 2: Use different query keys

If components need different shapes, use different cache keys:

```typescript
// Dashboard: raw response for metadata access
useQuery({ queryKey: ['items', 'raw'], queryFn: () => api.get('/items') })

// List page: unwrapped array
useQuery({ queryKey: ['items', 'list'], queryFn: async () => {
  const data = await api.get('/items')
  return data.items
}})
```

### Option 3: Centralize data fetching

Define each query once and import it:

```typescript
// queries/items.ts
export const itemsQuery = {
  queryKey: ['items'] as const,
  queryFn: () => api.get('/api/v1/items'),
}

// Both components use the same query definition
const { data } = useQuery(itemsQuery)
const items = data?.items ?? []
```

### Error Boundary Fix

Reset the error boundary on route changes to prevent one page's crash from locking out all pages:

```tsx
function RootLayout() {
  const location = useLocation()
  return (
    <ErrorBoundary key={location.pathname}>
      <Outlet />
    </ErrorBoundary>
  )
}
```

## Verification Checklist

- [ ] Search codebase for duplicate `queryKey` values across components: `grep -rn "queryKey.*\[" src/`
- [ ] For each duplicate key, verify the queryFn returns the same shape
- [ ] Test by navigating between pages that share cache keys (both orderings: A→B and B→A)
- [ ] Verify error boundary resets on navigation (not just on "Try again" click)
- [ ] Hard refresh (Cmd+Shift+R) and re-test full navigation flow

## Diagnostic

Quick check for cache key collisions in a codebase:

```bash
# Find all queryKey definitions and sort to spot duplicates
grep -rn "queryKey:" src/ | sed "s/.*queryKey://" | sort | uniq -d
```

If any keys appear more than once, verify the corresponding queryFn return shapes match.

## Tradeoffs

- **Option 1** (defensive normalization) adds runtime type-checking overhead but is the most resilient to future changes
- **Option 2** (different keys) fragments the cache — the same API call may be made multiple times
- **Option 3** (centralized queries) is the cleanest but requires refactoring existing components

## Applies To

This pattern applies to any client-side cache that:
- Uses a key-based lookup (React Query, SWR, Apollo Client, Relay)
- Shares the cache globally across components
- Allows different components to define different queryFn/fetcher functions for the same key
- Serves stale data before revalidating
