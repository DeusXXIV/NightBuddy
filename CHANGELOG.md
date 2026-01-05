# Changelog

## Unreleased
- Reconciled overlay state on app start/resume to recover from native overlay drift.
- Added a wind-down planner card that maps steps to the scheduled bedtime.
- Added a screen-off goal timer card for a no-phone window.
- Added a caffeine cutoff card tied to the scheduled bedtime.
- Added a bedtime mode quick action on the home screen.
- Added blue-light goal progress and a morning check-in quick log card.
- Persisted the screen-off goal across app restarts.
- Added settings to customize blue-light goal minutes.
- Added quick preset buttons for blue-light goal durations.
- Added screen-off goal defaults and caffeine cutoff settings.
- Added bedtime mode options and a wind-down checklist editor.
- Added a sunset sync toggle for planning.
- Added location-based sunset sync and screen-off notifications.
- Added soundscapes with a sleep timer and CSV export for sleep logs.
- Added reorderable wind-down checklist and bedtime mode auto-off.
## 1.1.0 - 2025-12-27
- Avoided requesting reminder permissions on cold start unless reminders are enabled.
- Refactored overlay control to a single Dart authority with event-based scheduling.
- Improved overlay activation robustness when permissions are missing.


## 0.1.0 - 2025-12-15
- Added a custom NightBuddy app icon and generated platform assets via flutter_launcher_icons.
- Set the semantic versioning baseline to 0.1.0+1 as we move toward 1.0.0.
