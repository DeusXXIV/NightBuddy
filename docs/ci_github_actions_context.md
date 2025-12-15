# NightBuddy GitHub Actions Context

Use this as the context prompt when asking ChatGPT to write GitHub Actions for this repo.

## Project summary
- Flutter app: blue light filter with overlay scheduling, ads, and premium unlock.
- Entry points: `lib/main.dart`, app shell in `lib/app.dart`.
- Current version: `0.1.0+1` (`pubspec.yaml`); changelog in `CHANGELOG.md`.
- Icon source: `assets/icon/nightbuddy_icon.png` (generated via `dart run flutter_launcher_icons`).

## Key tooling
- Flutter SDK: Dart SDK constraint `^3.10.1` (Flutter 3.10+ expected).
- Tests: default `flutter test` (only widget/unit tests; no integration/device lab here).
- Static analysis: `dart --enable-asserts dev/bots/analyze.dart` (not present yet), so default to `flutter analyze`.

## CI expectations
- Triggers: `push`/`pull_request` to `main`.
- Steps (typical):
  1. Checkout with submodules disabled.
  2. Set up Flutter (stable channel) using `subosito/flutter-action@v2` or equivalent.
  3. Cache `~/.pub-cache` (Windows path differs; keep keyed by `pubspec.lock`).
  4. Run `flutter pub get`.
  5. Run `flutter analyze`.
  6. Run `flutter test`.
- Platforms: Linux runner is fine for analyze/test; no Android/iOS builds required for CI yet.
- Env: No secrets needed for analyze/test (ads/purchases are gated by `kIsWeb` so they won’t execute in tests).

## Artifacts / outputs
- None required today. If adding build jobs later, publish APK/IPAs or web build from `build/` as needed.

## GitHub repo
- Remote: `https://github.com/DeusXXIV/NightBuddy`

## .gitignore highlights
- Flutter build outputs (`build/`, `.dart_tool/`, `.flutter-plugins*`, `/android/app/*/` variants).
- Platform-specific ignores under `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`.
