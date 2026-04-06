---
id: "space-y-silent-failure-inline-children"
title: "space-y-* silently fails when direct children are inline elements (e.g. <a> / <Link>)"
type: troubleshooting
status: validated
confidence: high
revision: 1

languages:
  - language: typescript
    versions: ">=4.x"
  - language: javascript
    versions: ">=ES2015"

frameworks:
  - ecosystem: npm
    name: tailwindcss
    version: ">=3.x"
  - ecosystem: npm
    name: react
    version: ">=18.x"
  - ecosystem: npm
    name: "@tanstack/react-router"
    version: ">=1.x"

dependencies: []
runtime: ["browser"]
domain: error-handling
tags: [tailwind, space-y, inline, anchor, link, gap, flexbox, layout, margin-top, router]

introduced: 2026-03-20
last_verified: 2026-03-20
review_by: 2026-06-20

maintainers: ["@kanekoa"]
deprecated_date: null
superseded_by: null
related:
  - flex-viewport-height-constraint
sanitized: true
migration_note: null
notes: "Discovered while styling a team member list where OrgChip was wrapped in a <Link> and PersonChip was a bare <div>. space-y-6 had zero visible effect on the gap."
---

# space-y-* silently fails when direct children are inline elements (e.g. `<a>` / `<Link>`)

## Context

Any React component that wraps its root element in a router `<Link>` (TanStack Router, React Router, Next.js `<Link>`) renders as an `<a>` tag — which is `display: inline` by default. When these components are used as direct children of a `space-y-*` container alongside block-level siblings (e.g. bare `<div>`), the spacing appears to work for some children but is invisible for others, with no error or warning.

## Symptoms

- Vertical cards/tiles appear "stacked" with no gap even after increasing `space-y-*`
- Some items in a list have correct spacing; others (the `<Link>`-wrapped ones) don't
- Adding `space-y-8`, `space-y-12`, or larger values has no visible effect on the problem children
- Inspecting the DOM in DevTools shows `margin-top` is set on the element, but the element is `display: inline`

```tsx
// ❌ Broken — OrgChip renders <a> (inline), PersonChip renders <div> (block)
// space-y-6 applies margin-top to both, but it has no effect on inline <a>
<div className="space-y-6">
  {teamMembers.map(m =>
    m.type === 'org'
      ? <OrgChip key={m.id} org={m.item} />     // renders as <a> — no gap
      : <PersonChip key={m.id} person={m.item} /> // renders as <div> — gap works
  )}
</div>
```

## Root Cause

Tailwind's `space-y-*` applies `margin-top` via the CSS sibling combinator:

```css
.space-y-6 > :not([hidden]) ~ :not([hidden]) {
  margin-top: 1.5rem;
}
```

**`margin-top` on an inline element has no effect** per the CSS box model. Block and inline-block elements respect vertical margins; purely inline elements (`display: inline`) do not. Since HTML `<a>` tags default to `display: inline`, any router `<Link>` component that renders as `<a>` without an explicit `display: block` override is immune to `space-y-*`.

The bug is invisible in isolation — if all children are `<div>` it works; if all children are `<a>` it silently fails; if you mix them the inconsistency is confusing.

## Fix

Two complementary fixes — apply both for robustness:

**1. Replace `space-y-*` with `flex flex-col gap-*` on the container.**
`gap` on a flex container applies to all flex items regardless of their `display` type.

```tsx
// ✅ Fixed container
<div className="flex flex-col gap-4">
  {teamMembers.map(m =>
    m.type === 'org'
      ? <OrgChip key={m.id} org={m.item} />
      : <PersonChip key={m.id} person={m.item} />
  )}
</div>
```

**2. Add `block` to any `<Link>` wrapper used as a direct list child.**
This makes the `<a>` a block element so `space-y-*` would work too — but `flex flex-col gap-*` is the more reliable fix.

```tsx
// OrgChip — add block to Link className
<Link
  to="/orgs/$id"
  params={{ id: String(org.id) }}
  className="block hover:opacity-90 transition-opacity"
>
  {inner}
</Link>
```

## Verification Checklist

- [ ] Cards/tiles have visible, consistent vertical gap between all items
- [ ] Gap is uniform whether the child renders as `<a>` or `<div>`
- [ ] Increasing/decreasing the gap value produces proportional visual changes for all children
- [ ] DevTools confirms the container is `display: flex; flex-direction: column`

## Tradeoffs

- `flex flex-col` changes the layout model of the container. If any children rely on `block` stacking context (e.g. for z-index or margin collapse), switching to flex may affect them. Inspect for regressions.
- `flex-col` containers don't participate in normal flow margin collapse — this is usually desirable in a card list.
- Adding `block` to `<Link>` makes the anchor full-width, which is almost always correct for card-style links but may break inline link usage.
