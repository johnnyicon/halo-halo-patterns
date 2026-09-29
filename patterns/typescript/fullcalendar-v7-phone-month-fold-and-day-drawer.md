---
id: fullcalendar-v7-phone-month-fold-and-day-drawer
title: FullCalendar 7 on a Phone and a Desktop: Own Class Hooks, a Compact Month That Folds to the Week, and a Day Drawer
type: implementation
status: draft
confidence: high
revision: 1

languages:
  - TypeScript

frameworks:
  - ecosystem: npm
    name: react
    version: ">=18 <20"
  - ecosystem: npm
    name: "@fullcalendar/react"
    version: ">=7 <8"
  - ecosystem: npm
    name: tailwindcss
    version: ">=4 <5"

dependencies:
  - ecosystem: npm
    name: "@fullcalendar/core"
    version: ">=7 <8"

runtime:
  - Browser

domain: forms
tags:
  - react
  - typescript
  - calendar
  - fullcalendar
  - fullcalendar-7
  - mobile
  - container-queries
  - sticky
  - month-view
  - day-view
  - drawer
  - hashed-classnames
  - tailwind

introduced: 2026-09-29
last_verified: 2026-09-29
review_by: 2026-12-28

maintainers:
  - "@kanekoa"

deprecated_date: null
superseded_by: null
related:
  - fullcalendar-with-shadcn-daypicker-untitled-ui-patterns
sanitized: true
migration_note: "Written for @fullcalendar/react 7.x. The companion recipe (related) covers 6.x and the surrounding date controls; the option and class-name facts below do not apply to 6.x."
notes: "Recipe distilled from a community calendar shipped 2026-09-18 to 2026-09-29, verified by WebKit and Chromium browser suites at 375, 390, 800, 900, 1024, 1100, 1280 and 1440 wide."
---

# FullCalendar 7 on a Phone and a Desktop

## Context

One page renders a shared month calendar with `@fullcalendar/react` 7.1
(`dayGridPlugin`, `timeGridPlugin`, `listPlugin`, `interactionPlugin`, the
`classicTheme` plugin) for both desktop and phone. Version 7 changes three
things that decide the whole approach:

1. **Class names are hashed** (`fc-Ih`, `fc-classic-Jk3`). Nothing in CSS or
   in a browser test can target `.fc-event`, `.fc-toolbar-title` or
   `.fc-daygrid-day`. Every hook must be your own.
2. **Option names differ from 6.x**: `dayCellTopContent` (custom content in a
   day cell's top, replacing the number), `dayCellClass`, `eventClass`,
   `listDayClass`, `listDayHeaderContent`, `listDayHeaderInnerClass`,
   `listDayAltFormat` (there is no `listDaySideFormat`), `dayHeaderClass`,
   `slotLaneClass`, `moreLinkClass`, `popoverClass`. Content generators
   accept React nodes. `views` takes per-view `titleFormat`.
3. The theme sets a grid row's `display` from a compound of hashed classes
   that outranks any selector you can write against it.

The product requirement was the iPhone calendar's list arrangement on a
phone (a compact month on top, today selected, the day's list beneath, the
month folding to the selected week as the list scrolls) and, on a desktop, a
day that opens beside the month rather than under a full-height grid.

## Usage

### 1. Own class hooks, never the library's

```tsx
<FullCalendar
  dayCellClass={(info) => cn('cal-day', isToday(info.date) && 'cal-day-today', ymd(info.date) === selectedDay && 'cal-day-selected')}
  dayCellTopClass="cal-daytop"
  dayHeaderClass="cal-dow"
  eventClass={(info) => cn('cal-event', info.event.extendedProps.cls, info.view.type === 'listMonth' && 'cal-listev')}
  listDayClass={(info) => cn('cal-listday', info.isToday && 'cal-listday-today')}
  listDayHeaderInnerClass={(info) => cn('cal-listday-inner', info.level > 0 && 'cal-listday-alt')}
/>
```

Cells carry a stable `data-date` attribute. Browser suites locate events by
`.cal-event` and days by `.cal-day[data-date="…"]`, never by `fc-*`.

### 2. Compact phone month: marks, not chips

Detect the phone with a `matchMedia('(max-width: 767px)')` hook on the same
line the app's own sidebar appears. In month view on a phone pass
`events={[]}` to the grid and draw each day's marks yourself in
`dayCellTopContent` from the same per-day entry map the day list reads: a
sky glyph first, then one dot per item in its calendar's colour, capped at
five with a `+N`. Every cell keeps one short height; titles never enter
cells.

```tsx
dayCellTopContent={compact ? (info) => {
  const m = dayMarks(byDay.get(ymd(info.date)) ?? [])
  return (
    <span className="cal-daytop-inner">
      <span className="cal-daynum">{info.dayNumberText}</span>
      <span className="cal-marks">
        {m.glyphs.map((g, i) => <span key={i} className="cal-mark-glyph">{g}</span>)}
        {m.colours.map((c, i) => <span key={i} className="cal-mark" style={{ backgroundColor: c }} />)}
        {m.more > 0 && <span className="cal-mark-more">+{m.more}</span>}
      </span>
    </span>
  )
} : undefined}
```

### 3. The selected day is state, set by a wrapper click

`dateClick` did not fire for cells with custom top content. Put a click
handler on the wrapper `div` around `<FullCalendar>`: ignore clicks inside
`.cal-event`, the more-link and its popover; otherwise
`t.closest('[data-date]')` gives the day. On a phone render the day's list
under the grid with a "Today" chip in its heading.

### 4. Pin the month and fold it with the scroll

Wrap the month row and grid in a `position: sticky` block whose `top` is a
measured `--shell-top` (a `ResizeObserver` on the app header, so a notch
inset is included). Hold the block's flow box at its EXPANDED height
(measured once while at the top of the page) and make the lower part
transparent and `pointer-events: none`, so the list slides under the strip
with no gap and no scroll feedback loop.

On scroll:

```ts
const rows = [...grid.querySelectorAll('[role=row]')].filter((r) => r.querySelector('.cal-day'))
const sel = rows.findIndex((r) => r.querySelector('.cal-day-selected'))
if (sel < 0) return                                        // nothing to fold to: stay open
const rowH = rows[0].getBoundingClientRect().height
const natural = grid.scrollHeight + (grid.offsetHeight - grid.clientHeight)
const delta = rowH * (rows.length - 1)
const stuckAt = anchor.getBoundingClientRect().top + scrollY - stickTop  // anchor: a zero-height div before the block
const fold = Math.min(Math.max(0, scrollY - stuckAt), delta)
grid.style.height = fold > 0 ? `${natural - fold}px` : ''
grid.style.setProperty('--lift', `${(sel * rowH * fold) / delta}px`)
```

```css
.cal-grid.cal-compact [role=row]:has(.cal-day) { transform: translateY(calc(-1 * var(--lift, 0px))); }
.cal-grid.cal-compact .cal-dow { position: relative; z-index: 2; background: var(--card); }
```

A pixel of scroll is a pixel of fold; rows above the selected week slide
under the weekday letters, rows below clip away, and scrolling back unfolds
it. No state, nothing snaps. Measure the fold from where the block sticks,
not from the top of the page, or the month folds while the page title above
it is still scrolling away and a gap opens.

### 5. Give the day's list exactly the fold's room

```ts
const folded = pinnedHeight - delta
const room = document.documentElement.clientHeight - stickTop - folded - listMarginTop - mainPaddingBottom
list.style.minHeight = `${Math.max(0, room)}px`
```

Less, and an empty day cannot fold the month while a full day can, which
reads as the fold working on one day and not the next. More, and a one-event
day keeps scrolling after the fold and its only card slides under the
strip.

### 6. One row of controls on the phone

`‹ Month ›`, *Today* only when not on today, a menu behind the current view's
name holding Day / Week / Month / List and the calendars filter, and a plus.
Drop the year from the phone month title:

```tsx
views={narrow ? { dayGridMonth: { titleFormat: { month: 'long' } }, listMonth: { titleFormat: { month: 'long' } } } : undefined}
```

Hide the page title on every phone view; the tab bar already names the page.

### 7. The list view opens at today and names each day once

Mark today's day with `listDayClass` (`info.isToday`) and, on entering the
view, `scrollIntoView` it with `scroll-margin-top: var(--shell-top)`. Render
the day header yourself with `listDayHeaderContent`; the theme draws it into
a main and an alt slot, so hide the alt one:

```css
.cal-grid .cal-listday-alt { display: none; }
.cal-grid .cal-listev, .cal-grid .cal-listev * { white-space: normal; }
```

### 8. Desktop: the day opens in a drawer over the month

`dayPanel` state opens on a day click or a `?day=` deep link and closes on
Escape or a cross. Render the drawer only while open, `position: absolute;
right: 0` inside the layout box, with a short keyframe entrance
(`translateX(24px) → 0`, 200ms, none under `prefers-reduced-motion`). Never
push the month aside: a column that appears re-lays the grid out on every
open and close, which reads as a jolt; a drawer parked past the edge while
closed widens the page. Make the drawer its own `@container` so its rows take
the narrow shape (time and venue under the title), and let the under-grid
list stand in where the box is narrower than the drawer needs, chosen by the
same container query so the two never both show.

### 9. Theme specificity

When a rule must beat the theme's row `display`, it needs `!important`. Prefer
transforms and heights on your own elements, as above, so you rarely need it.

## Tradeoffs

- Drawing marks yourself means month cells no longer open events on tap; the
  day's list does. Right on a phone, wrong on a desktop, so it is gated on
  width.
- The fold rides on document scroll: exact and stateless, but the list area
  must always be tall enough to scroll through a fold, which leaves blank
  space under a short day (the phone's own calendar makes the same trade).
- A drawer covers the month's right columns while open; a pushed column would
  not, but it jolts the grid.
- `:has()` is required (Safari 15.4+, Chrome 105+).

## Verification checklist

- Phone (WebKit, 390 and 375 wide): Month opens first; no `.cal-event` chips
  in cells; marks present on days that have something; all cells within 2px
  of one height and under 64px; the month row's title fits with and without
  the *Today* button.
- Fold: scroll to `stuckAt + 320`; the grid loses more than 100px, the
  selected cell remains inside it, the pinned block's flow box is taller
  than its inner; scroll to 0 restores the height.
- One-event day: scrolled to the end, the card sits between the strip's
  bottom edge and the viewport bottom.
- List view: one header per day; today's carries the chip; the page is
  scrolled so today's header is in view.
- Desktop: a day click opens the drawer; `?day=` opens it; Escape closes it;
  the grid's width is identical before, during and after; `scrollWidth ===
  innerWidth` at 1440, 1280, 1100, 1024 and 900; at 900 the under-grid list
  shows instead.
