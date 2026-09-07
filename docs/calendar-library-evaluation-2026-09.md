# Calendar library evaluation and decision record

**Reviewed:** 2026-09-07

**Decision:** Use FullCalendar for event scheduling, shadcn/ui's Calendar backed by React DayPicker for date-selection controls, and Untitled UI/React Aria patterns for the surrounding product experience and custom accessible controls.

## Scope

This evaluation covers a reusable React calendar approach for systems that may need both a scheduling surface and date-selection controls. It distinguishes a calendar that displays appointments or events from a calendar that returns a date or date range to a form.

## Executive summary

The candidate libraries are different layers of the interface:

- FullCalendar is the scheduling engine. It provides month, week, and day event views, plugins, event rendering, and interaction hooks.
- React DayPicker is a date-grid engine. It provides single, multiple, range, custom selection, localization, time-zone, and accessibility capabilities.
- shadcn/ui is a source-owned component layer. Its documented Calendar component is built on React DayPicker and adds Tailwind-oriented styling and composition.
- Untitled UI is a visual and source-code pattern library. Its React calendar examples use React Aria and Tailwind and demonstrate the surrounding toolbar, event density, overflow, and detail-panel decisions.
- MUI DateCalendar is a strong date-selection component, but adopting it only for this feature would add the MUI styling and date-adapter ecosystem.
- react-calendar is a lightweight date grid and is not a suitable foundation for a full event scheduler.

## Candidates considered

| Candidate | Role | Evidence and fit | Decision |
| --- | --- | --- | --- |
| [FullCalendar](https://fullcalendar.io/docs/react) | Event scheduler | React adapter, month/week/day views, plugins, event handlers, and custom event content. The open-source core is MIT; premium plugins have separate commercial licensing. | Selected for the main calendar surface |
| [React Big Calendar](https://github.com/bigcalendar/react-big-calendar) | Event scheduler | MIT React calendar with month/week/day/agenda views, date localizers, and a drag-and-drop add-on. Strong alternative if a simpler React-first event surface is preferred. | Keep as fallback |
| [React DayPicker](https://daypicker.dev/) | Date picker/calendar engine | MIT, customizable, supports single/multiple/range selection, WCAG 2.1 AA, time zones, and international calendars. | Selected through shadcn/ui for date controls |
| [shadcn/ui Calendar](https://ui.shadcn.com/docs/components/calendar) | Source-owned UI wrapper | The documented Calendar is built on React DayPicker and is installed into the consuming app's component directory. | Selected as the date-control presentation layer |
| [Untitled UI React calendars](https://www.untitledui.com/react/components/calendars) | UI and source pattern | React Aria and Tailwind examples cover month/week/day event layouts, event density, overflow, and detail presentation. | Use as the visual and interaction reference |
| [React Aria Calendar](https://react-aria.adobe.com/Calendar) | Accessible calendar primitive | Strong keyboard semantics, international calendar systems, time-zone-aware date values, and composable calendar cells. | Use where custom controls need React Aria behavior |
| [MUI DateCalendar](https://mui.com/x/react-date-pickers/date-calendar/) | Date picker | Mature validation, localization, and views, with an active MUI X ecosystem. Requires MUI and a date-library adapter. | Conditional option when the host app already uses MUI |
| [react-calendar](https://www.react-calendar.com/) | Lightweight date grid | Simple, CSS-customizable, and dependency-light, but has no native event-scheduling model. | Not selected for scheduling |

## Popularity and maintenance signals

These numbers are directional ecosystem signals, not active-user counts and should be refreshed when this note is reviewed:

- FullCalendar has roughly 1.8 million weekly npm downloads for its React package and approximately 19,000 GitHub stars. Its releases page shows an active 6.1.x line. [npm](https://www.npmjs.com/package/@fullcalendar/react) [releases](https://github.com/fullcalendar/fullcalendar/releases)
- React Big Calendar has roughly 1 million weekly npm downloads and approximately 9,000 GitHub stars. Its releases include a 1.19.6 maintenance release from May 2026. [npm](https://www.npmjs.com/package/react-big-calendar) [releases](https://github.com/bigcalendar/react-big-calendar/releases)
- React DayPicker has approximately 6,800 GitHub stars and a current v10 release line. [GitHub](https://github.com/gpbl/react-day-picker) [releases](https://github.com/gpbl/react-day-picker/releases)
- MUI X has an established maintainer and release ecosystem, with Community date/time pickers available under the MIT offering. [licensing](https://mui.com/x/introduction/licensing/) [release notes](https://mui.com/x/whats-new/)

## Decision architecture

```text
FullCalendar
  Owns the event grid, event positioning, views, navigation, and calendar interaction hooks.

shadcn/ui Calendar + React DayPicker
  Owns appointment-form dates, filters, mini calendars, and date-range inputs.

Untitled UI patterns
  Owns the visual language for the toolbar, event cards, overflow, filters, drawers, and empty states.

React Aria
  Supplies accessible behavior for custom date controls and surrounding interaction primitives.
```

FullCalendar should remain the single source of truth for rendering event positions. React Aria Calendar or DayPicker should not be placed inside the same event grid as a second competing calendar implementation. They belong in form fields, filters, mini calendars, or custom controls around the scheduler.

## Product implementation guidance

1. Build a toolbar using the host design tokens: Today, previous/next navigation, the visible date range, view selection, and the primary create action.
2. Feed FullCalendar a normalized event projection from the application domain. Keep recurrence, permissions, conflicts, audit data, and time-zone policy outside the component.
3. Use FullCalendar's event-content and class hooks to render compact Untitled-style event cards without replacing its positioning engine.
4. Use a `+N more` pattern for crowded month cells. Do not shrink event labels below readable targets to avoid overflow.
5. Open event details and appointment creation in a drawer or dialog using the host's source-owned components.
6. Use shadcn/ui Calendar for date fields and range selection. Set the user's time zone deliberately when a selected date is converted to a timestamp.
7. On narrow screens, prefer an agenda or day-list presentation rather than forcing a desktop week grid into a small viewport.

## Recheck triggers

Review this decision when the product needs resource timelines, advanced recurrence editing, external calendar synchronization, offline scheduling, very large event sets, or commercial-license restrictions. Also review when the host design system changes from Tailwind/shadcn to MUI or another component system.

## Sources

- [FullCalendar React documentation](https://fullcalendar.io/docs/react)
- [FullCalendar licensing and pricing](https://fullcalendar.io/pricing)
- [React DayPicker documentation](https://daypicker.dev/)
- [shadcn/ui Calendar documentation](https://ui.shadcn.com/docs/components/calendar)
- [Untitled UI React calendar components](https://www.untitledui.com/react/components/calendars)
- [React Aria Calendar documentation](https://react-aria.adobe.com/Calendar)
- [MUI DateCalendar documentation](https://mui.com/x/react-date-pickers/date-calendar/)
- [react-calendar documentation](https://www.react-calendar.com/)

