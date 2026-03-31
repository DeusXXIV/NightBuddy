# NightBuddy Agent Guide

## Purpose
Use this file as the maintained source of truth for how agents should approach testing work in this repo.
Keep it updated whenever the test strategy, CI contract, major test helpers, or release gates change.

## Testing Principles
- Follow the Flutter testing pyramid from official docs: prefer many fast unit and widget tests, plus a small number of high-value integration tests for critical end-to-end flows.
- Add a regression test for every user-facing bug fix and every non-trivial state bug.
- Prefer deterministic tests. Fake time, storage, audio, overlay, premium, and notification services instead of using real platform behavior.
- Keep tests focused on user outcomes and state transitions, not implementation trivia.
- Do not rely on test ordering. Each test must set up its own state and provider overrides.

## What To Test
- Pure state and serialization logic: add unit tests in `test/app_state_*.dart`, `test/sleep_metrics_test.dart`, and similar focused files.
- Service/controller behavior: add direct tests with fakes, following the pattern in `test/sleep_audio_service_test.dart`.
- Screen flows and navigation: add widget tests, following the pattern in `test/home_screen_test.dart`, `test/root_shell_test.dart`, and `test/schedule_screen_test.dart`.
- Critical app journeys: promote only the highest-value paths to `integration_test/` when widget tests are not enough.

## Repo-Specific Rules
- When a feature touches Riverpod state, prefer testing it through provider overrides rather than live services.
- For platform-facing code, add a fake or injectable boundary first, then test against that boundary.
- When a feature adds a new persisted setting, add a round-trip serialization test in `test/app_state_settings_test.dart`.
- When a feature changes a major screen, add or update at least one widget test that proves the user can reach and use the changed flow.
- Keep Home/Tonight tests focused on current user journeys, since those screens drive the product.

## CI Contract
- The repo CI must fail on formatting drift, analyzer errors, and failing tests.
- Current CI expectations:
  - `flutter pub get`
  - `dart format --output=none --set-exit-if-changed lib test`
  - `flutter analyze`
  - `flutter test`
- If `integration_test/` is added, CI should run those tests separately instead of folding them into the main widget/unit test command.
- Keep GitHub Actions concurrency enabled so stale pushes do not waste CI minutes.

## Commands
- Local verification:
  - `dart format lib test`
  - `flutter analyze`
  - `flutter test`
- Targeted verification:
  - `flutter test test/home_screen_test.dart`
  - `flutter test test/app_state_settings_test.dart`
  - `flutter test test/sleep_audio_service_test.dart`

## Maintenance
- Update this file when:
  - a new test layer is introduced
  - CI commands or required gates change
  - shared fakes/helpers become the preferred pattern
  - major screens or services shift enough that the current testing guidance is stale
