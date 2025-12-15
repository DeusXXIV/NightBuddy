# NightBuddy

NightBuddy is a blue light filter with overlay control, scheduling, and monetization (ads + premium unlock).

## Features
- Screen tint overlay with presets and manual tuning.
- Scheduling (off/always/specific times).
- Premium unlock flow (removes ads, unlocks extra warmth/controls).
- Google Mobile Ads for interstitials/banners.

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
- Current app version: `0.1.0+1` (see `pubspec.yaml` and `CHANGELOG.md`).
