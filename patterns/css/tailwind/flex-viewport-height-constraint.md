---
id: flex-viewport-height-constraint
title: "Flex Layouts Require Explicit Height Constraints for Viewport-Pinned Children"
type: debugging-workflow
status: draft
confidence: high
revision: 1
languages: [typescript, html]
frameworks: [react, tailwindcss, shadcn-ui]
domain: frontend
tags: [flexbox, viewport, height, overflow, scroll, layout, chat-ui, pinned-footer]
introduced: 2026-02-24
last_verified: 2026-02-24
review_by: 2026-05-24
sanitized: true
---

# Pattern: Flex Layouts Require Explicit Height Constraints for Viewport-Pinned Children

---

## Problem

**Symptom:**
- A chat input bar or footer component scrolls off-screen instead of staying pinned at the bottom
- A scrollable list (e.g., sessions sidebar) pushes the entire page height beyond the viewport
- Using `h-full` and `flex-1` on children but they expand to content size, not viewport size
- `overflow-hidden` on a child doesn't prevent the parent from growing

**Example:**
```html
<!-- Broken: SidebarInset has no height/flex constraint -->
<div class="h-screen">
  <SidebarInset>           <!-- ❌ not flex-col, no height -->
    <TopStatusBar />
    <main class="flex-1 overflow-hidden p-6">  <!-- flex-1 does nothing here -->
      <SessionsPage />     <!-- grows to content height -->
    </main>
  </SidebarInset>
</div>
```

## Root Cause

Flexbox `flex-1` only constrains a child's size when the parent:
1. Is itself a flex container (`display: flex` with `flex-direction: column`)
2. Has a **defined height** (explicit or inherited from a constrained ancestor)

If any link in the ancestor chain is missing flex-column layout or a height constraint, `flex-1` children will grow to their content size, pushing siblings (like a chat input) off-screen.

## Fix

Every ancestor in the layout chain must propagate the height constraint:

```html
<!-- Fixed: explicit flex-col + h-screen on every ancestor -->
<div class="h-screen">
  <SidebarInset class="flex flex-col h-screen overflow-hidden">
    <TopStatusBar />                              <!-- shrink-0 -->
    <main class="flex-1 overflow-hidden flex flex-col p-6">
      <SessionsPage class="flex flex-1 overflow-hidden">
        <SessionsList class="w-72 overflow-y-auto" />  <!-- scrolls independently -->
        <ChatArea class="flex flex-1 flex-col">
          <Transcript class="flex-1 overflow-y-auto" /> <!-- scrolls independently -->
          <ComposerBar class="shrink-0" />              <!-- pinned to bottom -->
        </ChatArea>
      </SessionsPage>
    </main>
  </SidebarInset>
</div>
```

## Key Rules

1. **Every ancestor needs `flex flex-col`** from the viewport root to the scrollable child
2. **One ancestor must set `h-screen`** (or equivalent fixed height) to anchor the chain
3. **Scrollable areas use `flex-1 overflow-y-auto`** — they fill remaining space and scroll internally
4. **Pinned elements use `shrink-0`** — they never collapse and stay at their natural size
5. **`overflow-hidden`** on a parent prevents content bleed but only works if the parent's height is actually constrained

## Detection Checklist

- [ ] Is there a `h-screen` (or `h-dvh`) somewhere in the ancestor chain?
- [ ] Is every ancestor between `h-screen` and the scrollable child using `flex flex-col`?
- [ ] Are scrollable areas using `overflow-y-auto` (not `overflow-hidden`)?
- [ ] Are pinned elements using `shrink-0`?
- [ ] Is any ancestor using `overflow-auto` (which makes the parent scroll instead of constraining children)?

## Common Mistakes

- Using `h-full` on a child whose parent has no defined height → `h-full` resolves to `auto` (content height)
- Using `overflow-auto` on a parent instead of `overflow-hidden` → parent scrolls, children don't constrain
- Using a component wrapper (like shadcn `SidebarInset`) that doesn't pass through flex/height classes → breaks the chain
- Negative margins (`-m-6`) to cancel parent padding → can confuse height calculation if `h-full` is used instead of `flex-1`

## Related

- Tailwind docs: [Flex utilities](https://tailwindcss.com/docs/flex)
- MDN: [Controlling ratios of flex items along the main axis](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_flexible_box_layout/Controlling_ratios_of_flex_items_along_the_main_axis)
