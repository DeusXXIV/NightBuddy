# Changelog

## Unreleased
- No changes yet.

## 2.0.0 - 2026-04-01
- Reorganized the app into dedicated `Tonight`, `Journal`, `Audio`, and `Settings` tabs for a clearer nightly flow.
- Added a guided Tonight experience with step-focused progression, carry-over support, and calmer done-for-tonight states.
- Expanded bedtime support with Mind Unload, Environment Check, a dedicated wind-down routine editor, and usual-night defaults.
- Improved filter tuning with a mock phone preview, better preset guidance, favorites, and faster repeat actions.
- Added shared sleep-audio playback with favorites, remembered timers, live status, and `Start usual night` automation.
- Standardized premium policy and in-app upgrade treatment across audio, journal, settings, onboarding, and schedule flows.
- Strengthened test/CI coverage with repo-level testing guidance, updated GitHub Actions checks, and broader widget/service regression coverage.

## 1.2.0 - 2026-01-17
- Added premium gating for custom presets, weekly trends, and CSV export.
- Added Insights v1 with bedtime consistency score and 7-day trend summary.
- Polished sunset sync with clearer preview and updated timing details.
- Refined onboarding flow with a focused 3-step setup.
- Added in-app review prompt after wind-down completion milestones.

## 1.1.0 - 2025-12-27
- Avoided requesting reminder permissions on cold start unless reminders are enabled.
- Refactored overlay control to a single Dart authority with event-based scheduling.
- Improved overlay activation robustness when permissions are missing.


## 0.1.0 - 2025-12-15
- Added a custom NightBuddy app icon and generated platform assets via flutter_launcher_icons.
- Set the semantic versioning baseline to 0.1.0+1 as we move toward 1.0.0.
