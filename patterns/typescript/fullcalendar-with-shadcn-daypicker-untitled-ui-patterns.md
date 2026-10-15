---
id: fullcalendar-with-shadcn-daypicker-untitled-ui-patterns
title: FullCalendar Scheduling with shadcn Date Controls and Untitled UI Patterns
type: implementation
status: draft
confidence: medium
revision: 1

languages:
  - TypeScript

frameworks:
  - ecosystem: npm
    name: react
    version: ">=18 <20"
  - ecosystem: npm
    name: "@fullcalendar/react"
    version: ">=6 <7"

dependencies:
  - ecosystem: npm
    name: "@fullcalendar/core"
    version: ">=6 <7"
  - ecosystem: npm
    name: "@fullcalendar/daygrid"
    version: ">=6 <7"
  - ecosystem: npm
    name: "@fullcalendar/timegrid"
    version: ">=6 <7"
  - ecosystem: npm
    name: "@fullcalendar/interaction"
    version: ">=6 <7"
  - ecosystem: npm
    name: "react-day-picker"
    version: ">=9 <11"

runtime:
  - Browser

domain: forms
tags:
  - react
  - typescript
  - calendar
  - scheduling
  - appointments
  - fullcalendar
  - shadcn
  - react-day-picker
  - react-aria
  - tailwind

introduced: 2026-09-07
last_verified: 2026-09-07
review_by: 2027-03-07

maintainers:
  - "@kanekoa"

deprecated_date: null
superseded_by: null
related:
  - fullcalendar-v7-phone-month-fold-and-day-drawer
sanitized: true
migration_note: null
notes: "Recipe based on the calendar-library evaluation dated 2026-09-07. FullCalendar owns event layout; shadcn/ui and React DayPicker own date inputs; Untitled UI and React Aria guide surrounding presentation and accessible custom controls."
---

# FullCalendar Scheduling with shadcn Date Controls and Untitled UI Patterns

## Context

An application needs a reusable calendar feature that may show appointments or other events, while also using date-selection controls inside forms and filters. A full scheduler and a date picker are different interfaces. The scheduler must position events across views and time slots; the date picker must return a date or range with predictable keyboard, locale, and time-zone behavior.

The implementation should preserve a source-owned design system. Untitled UI is used as a visual and composition reference, not treated as an opaque scheduler dependency. Its React examples use React Aria and Tailwind, which makes the patterns useful for accessible controls and event presentation around FullCalendar.

## Usage

Use this component boundary:

```text
CalendarPage
  CalendarToolbar
  CalendarFilters
  FullCalendar
  AppointmentDetailsDrawer
  AppointmentForm
    shadcn/ui Calendar backed by React DayPicker
```

FullCalendar owns:

- Month, week, day, and agenda-style event views
- Event positioning, overlap handling, and time slots
- Visible-range navigation
- `dateClick`, `select`, `eventClick`, and event-change hooks
- Event rendering hooks and calendar-specific overflow behavior

The application owns:

- The appointment/event domain model
- Recurrence rules and expansion policy
- Time-zone policy and conversion to display values
- Permissions, conflict detection, audit history, and persistence
- Loading, error, empty, and optimistic-update states

Use shadcn/ui's Calendar for date fields, date ranges, filters, and mini calendars. The shadcn Calendar is built on React DayPicker, so use DayPicker's selection modes and localization APIs rather than building another date-grid implementation.

Use Untitled UI patterns for the toolbar, event-card hierarchy, color semantics, overflow treatment, drawer/dialog layout, and responsive composition. Use React Aria patterns or components when a custom date control needs their keyboard and internationalization behavior.

Representative FullCalendar wiring:

```tsx
<FullCalendar
  plugins={[dayGridPlugin, timeGridPlugin, interactionPlugin]}
  initialView="dayGridMonth"
  events={calendarEvents}
  selectable
  dateClick={handleDateClick}
  select={handleDateSelect}
  eventClick={handleEventClick}
  eventContent={renderEventCard}
  dayMaxEvents={3}
  moreLinkClick="day"
/>
```

`renderEventCard` should return a small, readable event representation. It should not contain sensitive details that are not appropriate for the current user's scope. Selecting an event should open the details drawer rather than forcing complex editing into the event chip.

## Tradeoffs

FullCalendar is the scheduling engine because it supplies the difficult event-grid behavior. The tradeoff is that its default visual language must be overridden carefully with the application's tokens and event-content hooks.

shadcn/ui and React DayPicker are used for date controls because they fit a Tailwind/source-owned system. The tradeoff is that the application owns the copied shadcn component and must keep it compatible with its chosen DayPicker version.

Untitled UI patterns provide a strong visual starting point without making the application depend on a separate calendar runtime. The tradeoff is that copying the pattern also transfers responsibility for responsive behavior, event overflow, focus management, and future maintenance.

React Aria improves custom accessibility and internationalization behavior. The tradeoff is that React Aria Calendar is a composable calendar primitive, not a replacement for FullCalendar's event scheduler.

Do not add MUI DateCalendar solely for this recipe unless the host application already uses MUI. Avoid combining two competing event-grid engines in one route.

## Verification checklist

- [ ] FullCalendar is the only component positioning events on the main scheduling surface.
- [ ] Month, week, and day views use the same normalized event projection.
- [ ] Event clicks, date clicks, and range selections have explicit loading and error behavior.
- [ ] Appointment dates and timestamps have an explicit time-zone policy.
- [ ] Recurrence, conflict detection, permissions, and audit history remain in the application domain layer.
- [ ] Month-cell overflow uses a readable `+N more` affordance.
- [ ] Event cards expose meaningful accessible labels and do not rely only on color.
- [ ] Keyboard focus is visible for toolbar controls, date controls, dialogs, and event actions.
- [ ] Date fields use the host design tokens and do not introduce a second visual system.
- [ ] Mobile behavior uses an agenda or day-list fallback when the week grid is not usable.
- [ ] The calendar is checked with realistic sparse, dense, overlapping, disabled, and error states.
- [ ] FullCalendar core and any premium plugins have been reviewed against the product's licensing requirements.

## References

- [FullCalendar React documentation](https://fullcalendar.io/docs/react)
- [FullCalendar pricing and licensing](https://fullcalendar.io/pricing)
- [React DayPicker documentation](https://daypicker.dev/)
- [shadcn/ui Calendar documentation](https://ui.shadcn.com/docs/components/calendar)
- [Untitled UI React calendar components](https://www.untitledui.com/react/components/calendars)
- [React Aria Calendar documentation](https://react-aria.adobe.com/Calendar)

