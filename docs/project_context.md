# Project Context

## Overview
NightBuddy is a blue light filter with overlay control, scheduling, and monetization (ads + premium unlock). It helps users prepare for sleep hours before bedtime with a calm, guided night routine.

## Features
- Screen tint overlay with presets and manual tuning.
- Scheduling (off/always/specific times).
- Premium unlock flow (removes ads, unlocks extra warmth/controls).
- Google Mobile Ads for interstitials/banners.
- Quick flashlight toggle (in-app card and notification action).
- Snooze the filter for quick breaks (15/30 minutes) with resume control.
- Wind-down planner timeline tied to your scheduled bedtime.
- Wind-down ramp that gradually warms the filter before scheduled start.
- Fade-out ramp that gently eases the filter off after schedule end.
- Sleep tips and a simple manual sleep journal with quality notes.
- Wind-down routine checklist and sleep goal progress insights.
- Sleep score insights, logging streaks, and bedtime/wake averages.
- Bedtime reminders tied to your schedule and morning check-in reminders.
- Caffeine cutoff card based on scheduled bedtime.
- Screen-off goal timer for a short no-phone window before bed.
- Bedtime mode quick action to enable the filter.
- Blue-light goal card for warm-filter minutes before bed, with a settings slider.
- Morning check-in quick log card for sleep quality and notes.
- Screen-off goal and caffeine cutoff preferences in Settings.
- Bedtime mode options (preset selection, auto screen-off, auto-off timer).
- Wind-down checklist editor in Settings.
- Sunset sync toggle (location-based) for wind-down planning.
- Screen-off goal notifications (start/end).
- Notification schedule card with preview actions.
- Soundscapes with a sleep timer.
- Sleep journal CSV export.
- Pause until the next scheduled change.
- Overlay watchdog sync banner when native overlay mismatches app state.
- Multiple custom presets with create/rename/delete.
- High-contrast mode toggle.

## Recent Improvements
- Persisted screen-off goal state and added default duration settings.
- Added caffeine cutoff and blue-light goal sliders with quick presets.
- Added bedtime mode options (preset selection + auto screen-off).
- Added wind-down checklist editor in Settings.
- Added location-based sunset sync, screen-off notifications, and soundscapes.
- Added CSV export for sleep journal logs.
- Added bedtime mode auto-off timer and reorderable checklist.
- Added notification previews and upcoming reminder visibility.
- Added overlay watchdog sync and guidance banner.
- Added multi custom presets and management UI.
- Added high-contrast accessibility toggle.
- Added weekly summary expansion with more insights and sharing details.

## Overlay Control Model
- Single source of truth: `filterEnabled`.
- Schedule and notification are input events only.
- App start/resume reconciles `filterEnabled` with native overlay state.
- Details: `docs/overlay_architecture.md`, `docs/scheduling_model.md`,
  `docs/notification_contract.md`.

## Requirements
- Flutter SDK (3.10+ recommended).
- Android/iOS SDKs for mobile builds; Chrome/Edge for web.

## Getting Started
```bash
flutter pub get
flutter run  # pick your device; for web: flutter run -d edge
```

## Icon assets
- Source icon: `assets/icon/nightbuddy_icon.png`.
- Generated via `flutter_launcher_icons`:
```bash
dart run flutter_launcher_icons
```

## Versioning
- Current app version: `1.1.0+4` (see `pubspec.yaml` and `CHANGELOG.md`).
- We follow semver for releases and increment the build number for store uploads.

## Core Principles
- Single source of truth for overlay state (`filterEnabled`).
- Schedule and notifications are input events only.
- Manual toggles are always allowed outside of explicit schedule events.
- Sync with native overlay state on app start/resume.

## Feature Ideas (Night Routine)
- Adaptive schedule: bedtime suggestions based on recent logs, with gentle nudges.
- Sunset sync: automatic warm-up tied to local sunset, plus lighting tips.
- Sleep prep checklist: customizable routine steps with streaks and quick taps.
- Morning check-in: quick mood/energy/quality rating for better insights.
- Sleep tips carousel: personalized tips based on recent habits.
- Alarm handoff: optional wind-down start based on alarm time.
- Data export: CSV for sleep journal entries and weekly summaries.
- Wind-down checklist reordering and templates.
- Screen-off goal notifications to start/end the no-phone window.
- Bedtime mode extras: optional auto-snooze and preset preview.
