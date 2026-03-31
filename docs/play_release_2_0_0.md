# NightBuddy 2.0.0 Play Release Pack

## Release identity
- Version name: `2.0.0`
- Version code: `7`
- Package: `com.nightbuddy.app`
- Release date prepared: `2026-04-01`

## Suggested Play "What's new"
Sleep support is now organized around a calmer nightly flow. NightBuddy 2.0 adds dedicated Tonight, Journal, Audio, and Settings sections, plus new tools like Mind Unload, Environment Check, usual-night defaults, and a stronger guided bedtime routine.

## Longer release notes
- Rebuilt the app around dedicated Tonight, Journal, Audio, and Settings tabs.
- Added a more guided Tonight routine with clearer next steps and calmer completion states.
- Added Mind Unload and Environment Check to support settling in before bed.
- Added usual-night defaults, favorite presets, favorite sleep music, and faster repeat actions.
- Improved sleep audio with live playback status, remembered timers, and shared playback behavior.
- Refined premium messaging and setup flows for a more consistent experience.
- Expanded testing and release checks for a safer update.

## Repo-side status
- Version bumped to `2.0.0+7` in `pubspec.yaml`.
- Changelog updated for `2.0.0`.
- In-app version label updated to `2.0.0`.
- Android release signing files are present in `android/`.
- Package ID and billing SKU are already configured.
- `flutter analyze` passes with no issues.
- `flutter test` passes (`38` tests).
- Signed release bundle built successfully at `build/app/outputs/bundle/release/app-release.aab`.

## Remaining manual blockers
- Terms of Service URL is still blank in `lib/constants/app_links.dart`.
- Play Console App content/Data safety review still needs manual confirmation for this update.
- Store screenshots should be refreshed to reflect the current tabbed UI.

## Expected artifact
- `build/app/outputs/bundle/release/app-release.aab`
