# NightBuddy GitHub Actions Context

Use this as the context prompt when asking ChatGPT to write GitHub Actions for this repo.

## Project summary
- Flutter app: blue light filter with overlay scheduling, ads, and premium unlock.
- Entry points: `lib/main.dart`, app shell in `lib/app.dart`.
- Current version: `2.0.0+7` (`pubspec.yaml`); changelog in `CHANGELOG.md`.
- Icon source: `assets/icon/nightbuddy_icon.png` (generated via `dart run flutter_launcher_icons`).

## Key tooling
- Flutter SDK: Dart SDK constraint `^3.10.1` (Flutter 3.10+ expected).
- Tests: default `flutter test` (only widget/unit tests; no integration/device lab here).
- Static analysis: `flutter analyze`.

## CI expectations
- Triggers: `push`/`pull_request` to `main`.
- Concurrency: cancel superseded runs on the same branch/PR.
- Steps (typical):
  1. Checkout with submodules disabled.
  2. Set up Flutter (stable channel) using `subosito/flutter-action@v2` or equivalent.
  3. Cache `~/.pub-cache` (Windows path differs; keep keyed by `pubspec.lock`).
  4. Run `flutter pub get`.
  5. Run `dart format --output=none --set-exit-if-changed lib test`.
  6. Run `flutter analyze`.
  7. Run `flutter test`.
  8. If `integration_test/` exists, run it separately (for Linux CI: `xvfb-run -a flutter test integration_test -d linux`).
- Platforms: Linux runner is fine for analyze/test; no Android/iOS builds required for CI yet.
- Env: No secrets needed for analyze/test (ads/purchases are gated by `kIsWeb` so they won't execute in tests).

## Artifacts / outputs
- None required today. If adding build jobs later, publish APK/IPAs or web build from `build/` as needed.

## GitHub repo
- Remote: `https://github.com/DeusXXIV/NightBuddy`

## .gitignore highlights
- Flutter build outputs (`build/`, `.dart_tool/`, `.flutter-plugins*`, `/android/app/*/` variants).
- Platform-specific ignores under `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`.
