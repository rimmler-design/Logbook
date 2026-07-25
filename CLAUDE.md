# CLAUDE.md

## Project

Logbook — a native macOS time-tracking app for a freelance product designer. Built as a `MenuBarExtra` app using SwiftUI + SwiftData for persistence.

## Architecture

- **Persistence:** SwiftData `@Model` classes — `Project`, `Task`, `TimeEntry` (see `Logbook/Models.swift`). `Project → Task → TimeEntry`, with `Project.entries` also available directly (task is optional on `TimeEntry`).
- **State/timer logic:** centralized in `TimerEngine` (`Logbook/TimerEngine.swift`), an `@Observable` class. It owns `runningEntry` and guarantees only one entry runs at a time — `start()` always calls `stop()` first. **Any new tracking logic (including automatic tracking) must go through or coordinate with this engine — never build a second, independent timer loop that could race with it.**
- **UI:** `MenuBarView` is the compact popover (fixed 280pt width) reachable from the menu bar icon — status/quick-actions only. `MainView`, opened via `Window("Logbook")`, is the full window for anything heavier (lists, review flows, settings).
- **App entry:** `TimeTrackerApp.swift`.

## Current feature: automatic tracking

Full spec: `docs/PRD-automatic-tracking.md`. Read it before working on anything related to automatic/rule-based tracking, idle detection, or the review bucket — it defines both what to build and what not to build.

Key points to hold in every session:

- Extend the existing model (`EntrySource`, `TimeEntry`, new `TrackingRule`) — do not create a parallel schema.
- Automatic entries must never override or interrupt a manually-started running entry.
- Window titles: keep locally only, discard once an entry is `.finalized`; retain only while `.pendingReview` (for rule mismatches or idle-flagged time).
- Ambiguous automatic entries (no rule match, or idle-flagged) go to a review bucket — never silently discarded, never silently auto-assigned to a default project.

### Out of scope — do not build without explicit confirmation

- Cross-platform / Windows support (native SwiftUI only, decided against for this phase)
- Cloud sync or backup of any kind
- Calendar integration / meeting-based auto-logging
- ML/AI-based categorization beyond user-defined keyword rules
- Mobile app or companion app
- Team/multi-user features, sharing, or collaboration
- Invoicing, billing, or client-facing reports
- Export/import features
- A separate idle-review UI distinct from the rule-mismatch review bucket (they share one interface)
- Auto-creating projects from unmatched entries

## Conventions

- Target macOS only — do not add Windows/Linux-specific code or cross-platform abstractions unless asked.
- Model changes must stay backward-compatible with existing SwiftData models already bound to `MenuBarView`/`TimerEngine` — flag breaking changes before making them rather than proceeding silently.
