# Play Launch Checklist (NightBuddy)

Tasks that can be done now:
- [ ] Set the production Android package ID in `android/app/build.gradle.kts` (`applicationId`) and refactor the Kotlin package folder/name to match. Update `linux/CMakeLists.txt` and iOS/macos bundle IDs if you keep those platforms aligned.
- [ ] Replace AdMob IDs: `android/app/src/main/AndroidManifest.xml` meta-data and `lib/services/ads_service.dart` banner/interstitial IDs must use your real values.
- [ ] Configure release signing: add your keystore to `android/app` and wire it in `build.gradle.kts` release `signingConfig`.
- [ ] Configure Play Billing product IDs: ensure `_productIds` in `lib/services/premium_service.dart` matches the SKU you create in Play Console.
- [ ] Add hosted Privacy Policy and Terms URLs: set `kPrivacyPolicyUrl` and `kTermsOfServiceUrl` in `lib/constants/app_links.dart` and keep the in-app fallback text accurate.
- [ ] Update the store rate link package ID: `kAndroidPackageId` in `lib/constants/app_links.dart`.
- [ ] Verify Data Safety: declare ads (AdMob), billing, and permissions (`SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS`) with accurate collection/sharing answers.
- [ ] Build and test a release bundle: `flutter build appbundle --release` and sideload to verify overlay permission flow, ads, purchases, boot reminder, and notifications.

Notes:
- Actions in `OverlayService` now derive from `BuildConfig.APPLICATION_ID`, so package ID changes only need to happen in Gradle and the Kotlin package name.
- Keep a single source of truth for identifiers in `lib/constants/app_links.dart` to avoid string drift.
