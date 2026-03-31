# Play Launch Checklist (NightBuddy)

Current target release:
- Version: `2.0.0+7`
- Package: `com.nightbuddy.app`
- SKU: `nightbuddy_premium_lifetime`

Repo-side release readiness:
- [x] Android package ID is set to `com.nightbuddy.app` in `android/app/build.gradle.kts` and Kotlin package paths.
- [x] Release signing is configured through `android/key.properties` and `android/nightbuddy-release.jks`.
- [x] Billing SKU is defined in `lib/services/premium_service.dart`.
- [x] Privacy Policy URL is set in `lib/constants/app_links.dart`.
- [x] Store package ID link constant is set in `lib/constants/app_links.dart`.
- [x] App version is bumped in `pubspec.yaml` and reflected in `CHANGELOG.md`.
- [x] Release AAB builds successfully at `build/app/outputs/bundle/release/app-release.aab`.
- [ ] Terms of Service URL is still blank in `lib/constants/app_links.dart`.
- [ ] Release build still needs smoke-testing on a device/install.

Manual Play Console / release tasks:
- [ ] Upload the `2.0.0+7` Android App Bundle to the existing Play track as an update.
- [ ] Add release notes for `2.0.0` in Play Console.
- [ ] Review App content / Data safety for ads, billing, notifications, and overlay-related permissions.
- [ ] Confirm support email, website, privacy policy, and Terms of Service links are valid on the store listing.
- [ ] Verify the premium product `nightbuddy_premium_lifetime` is active in the same app.
- [ ] Refresh screenshots to match the current tabbed UI (`Tonight`, `Journal`, `Audio`, `Settings`).
- [ ] Use a staged rollout before full production release.

Release verification:
- [ ] Install the signed release build and verify overlay permission flow.
- [ ] Verify bedtime scheduling and reminder notifications.
- [ ] Verify premium purchase/restore behavior.
- [ ] Verify live ad behavior on release-safe test devices/accounts.
- [ ] Verify Rainbound playback and timer behavior on release build.

Notes:
- `OverlayService` actions derive from `BuildConfig.APPLICATION_ID`, so package changes remain centralized in Gradle/Kotlin package names.
- Keep identifiers and hosted legal URLs in `lib/constants/app_links.dart` as the single source of truth.
