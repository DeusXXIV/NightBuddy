# Dev Log

Use this file to capture changes that fixed a regression or solved a tricky issue.
Keep entries short and actionable so we can retrace what worked.

## 2026-04-01
- Release: Prepared NightBuddy `2.0.0+7` for a Play Store update, including changelog/version alignment and a dedicated Play release pack in `docs/play_release_2_0_0.md`.
- Release: Updated the Play launch checklist to reflect the current package ID, billing SKU, signing setup, and remaining manual blockers such as the missing Terms of Service URL.
- Verification: `flutter analyze` passed cleanly, `flutter test` passed (`38` tests), and `flutter build appbundle --release` produced `build/app/outputs/bundle/release/app-release.aab`.

## 2026-03-20
- Navigation: Rebuilt the app around dedicated `Tonight`, `Journal`, `Audio`, and `Settings` tabs instead of using Home as a feature browser.
- UX: Removed the old supporting-tools accordion from Home and replaced it with clearer cross-tab guidance so the landing screen stays focused on tonight.
- Premium: Moved premium status/upgrade entry into Settings instead of keeping premium in the primary tab bar.
- Cleanup: Removed dead Home-only utility card implementations left behind by the IA split so analyzer noise does not hide real regressions.
- Testing: Added/updated root-shell and Home widget coverage for the new tab structure and the quieter done-for-tonight state.
- UX: Reworked Journal into clearer sections (`At a glance`, `Tonight`, `History & trends`) so it reads like a destination instead of moved Home cards.
- UX: Reworked Audio into clearer sections (`Now playing`, `Quick start`, `Sleep music`, `Ambient soundscapes`) and kept usual-night audio defaults there.
- Testing: Updated root-shell and screen tests to cover the section-based Journal/Audio layouts.
- Refactor: Extracted the `Settle in` / tonight-plan card from `home_screen.dart` into `lib/features/home/widgets/tonight_plan_card.dart`.
- Cleanup: Removed the old embedded `Settle in` copy and its dead Home-only helpers after the extraction.
- Settings: Reframed section labels around setup/use (`Quick access`, `Night prompts`, `Night goals`, `Routine setup`, `Bedtime automation`, `Device & accessibility`, `Data & privacy`).
- Settings: Added a direct `Usual night defaults` entry so recurring bedtime setup does not stay buried across multiple screens.
- Settings: Converted the page into a true hub with dedicated setup screens for `Display & goals`, `Night prompts`, `Routine & bedtime`, and `Device & privacy`.
- Testing: Added direct Settings widget coverage for the hub entries and opening `Usual night defaults`.
- Refactor: Extracted Home filter/status UI into `lib/features/home/widgets/home_filter_sections.dart`.
- Cleanup: Removed the old embedded overlay banners, status card, preset carousel, sliders, and filter preview from `home_screen.dart`.
- Verification: `flutter analyze lib/features/home/home_screen.dart lib/features/home/widgets/home_filter_sections.dart test/root_shell_test.dart test/home_screen_test.dart` and `flutter test test/root_shell_test.dart test/home_screen_test.dart` both passed.
- Refactor: Extracted the remaining Home support UI into `lib/features/home/widgets/home_support_sections.dart`.
- Cleanup: Removed the old embedded carry-over card, cross-tab guide, debug card, schedule/reminder cards, premium CTA, ad area, and schedule helpers from `home_screen.dart`.
- Verification: `flutter analyze lib/features/home/home_screen.dart lib/features/home/widgets/home_support_sections.dart lib/features/home/widgets/home_filter_sections.dart test/root_shell_test.dart test/home_screen_test.dart` and `flutter test test/root_shell_test.dart test/home_screen_test.dart` both passed.
- UX: Rewrote user-facing copy in Home, Audio, Journal, Settings, Tonight, Usual Night Setup, and Wind-down Routine to remove internal/product-planning language.
- Premium: Standardized upsell cards and premium-lock snackbars with shared helpers in `lib/widgets/premium_ui.dart`.
- Cleanup: Replaced duplicate upgrade hint cards and inconsistent premium lock wording across audio, journal, settings, onboarding, schedule, and Home support UI.
- Premium: Centralized the actual free-vs-premium rules in `lib/constants/premium_policy.dart` and reused them in Premium, Audio, Settings, and notifier logic.
- Product: Premium screen now explains both the free tier and the premium tier instead of only listing paid benefits.
- Verification note: Flutter analyze/test commands timed out in this environment during the copy/premium consistency pass.
- Refactor: Moved Home's derived bedtime progress, audio/tracking summaries, carry-over selection, and overlay sync expectations into `lib/features/home/home_view_data.dart`.
- Cleanup: Removed the leftover inline summary helpers from `home_screen.dart` so the screen keeps moving toward orchestration instead of local state derivation.
- Verification note: `dart format`, `flutter analyze`, and `flutter test` all timed out again in this environment during the Home helper-layer refactor.
- UX: Tightened `Tonight` progression by adding an `After this` preview and an in-card `Current focus` label on the active step.
- UX: Simplified `Settle in` by collapsing schedule/defaults/routine links into a single `Adjust setup` menu so bedtime actions carry more visual weight.

## 2026-01-16
- Audio: Rainbound Lullaby playback restored by loading asset bytes via `rootBundle` and trying both `sounds/...` and `assets/sounds/...` paths.
- UI: Sleep journal history moved to a dedicated screen; sleep tips expanded and moved to a full-page view.
- Home flow: Unified Settle-in card and returned ambient soundscapes to the main home flow.
- Notes: If audio breaks again, run `flutter clean` and verify AAC decoding on the device.
- UX: Converted sleep journal end/edit and morning check-in flows to full-screen pages (no bottom sheets).
- UX: Removed remaining bottom sheets (legal, tips, journal flows) in favor of dedicated pages.

## 2026-01-17
- Premium: Gated weekly trends + CSV export and capped free custom presets at 2.
- Insights: Added bedtime consistency score and 7-day trend summary.
- Sunset sync: Added clearer preview details in Settings and Schedule.
- Onboarding: Consolidated into a 3-step setup flow.
- UX: Added in-app review prompt after wind-down milestones.

## 2026-03-06
- Refactor: Extracted Sleep Tips UI into `lib/features/home/widgets/sleep_tips_card.dart`.
- Refactor: Extracted Sleep Music + Ambient Soundscape UI into `lib/features/home/widgets/sleep_audio_cards.dart`.
- Home wiring: `home_screen.dart` now imports those widgets and removed duplicate in-file implementations.
- Verification: `flutter analyze` on updated files passes with no errors (only pre-existing info-level lints).

## 2026-03-19
- Refactor: Extracted Sleep Journal, Weekly Summary, Morning Check-in, and related journal screens into `lib/features/home/widgets/sleep_journal_widgets.dart`.
- Cleanup: Removed the duplicated in-file journal and morning check-in implementations from `lib/features/home/home_screen.dart`.
- Tests: Added a widget regression test for navigating from Sleep Journal to the dedicated Sleep History screen.
- Verification note: local `flutter analyze` / `flutter test` commands timed out in this workspace, so this refactor still needs a manual validation pass.
- Feature: Added persisted Mind Unload entries with categories (`Thought`, `Worry`, `Reminder`, `Gratitude`) plus a dedicated full-page screen.
- Home: Added a Mind Unload card to the main night flow so users can clear their head before bed.
- Feature: Added persisted Environment Check progress for nightly room setup (lights, comfort, alarm, bedside essentials).
- Home: Added an Environment Check card and a dedicated full-page checklist screen.
- Flow: Added a dedicated Tonight screen that guides the user through room setup, mind unload, wind-down, and screen-off steps.
- Home: Settle In now links to the Tonight flow as a clearer entry into the night routine.
- Preview: Replaced the plain filter preview box with a mock phone preview and added a full-screen preview route from Home.
- Navigation: Removed duplicate top-level Mind Unload and Environment Check cards from Home to reduce saturation.
- Home IA: Grouped audio, sleep tracking, and utilities into clearer expandable sections and promoted `Continue tonight` as the primary bedtime CTA.
- Home IA: Added section headers (`Tune tonight`, `Tonight`, `Supporting tools`) and renamed vague groups to `Audio for tonight` and `Before-bed extras`.
- Tests: Fixed Home widget regressions caused by the grouped layout and verified `flutter test` passes again (19 tests).
- UX: Changed Tonight from four equal-weight cards into a guided sequence with one active step, a progress summary, and completed steps moved below.
- UX: Settle In now shows a `Next:` summary so the main screen points to the next bedtime action instead of just listing status.
- UX: Removed the detailed wind-down checklist from Home so `Settle in` stays lighter; the full routine now lives in `Tonight`.
- UX: Tune filter now shows the active preset more clearly and adds a short "feel" label to keep the preview more intuitive than raw sliders.
- QoL: Added a saved favorite preset with a quick return action in the tuning card.
- QoL: Added a saved favorite sleep track plus a `Play favorite` shortcut in the sleep music card.
- QoL: Settle In now changes its primary CTA based on the next unfinished bedtime step so users can resume where they left off.
- QoL: Quick wind-down now prefers the bedtime preset and otherwise falls back to the saved favorite preset for faster repeat use.
- QoL: Settle In now offers a one-tap `Start usual night` action that uses favorite audio plus the preferred bedtime path.
- QoL: Sleep music now remembers the user's usual timer length and marks it in the timer row.
- QoL: Settle In now uses a calmer done-state message once the main bedtime steps are already complete.
- QoL: Supporting sections now show compact summaries so Home is easier to scan without opening every section.
- QoL: Audio, tracking, and extras now summarize live state directly in collapsed section headers for faster scanning.
- UX: Tonight now highlights `Current focus` and auto-anchors the active step when opened.
- Architecture: Sleep music playback now runs through a shared audio controller instead of staying local to the card widget.
- UX: Tune filter now shows the active preset more clearly and adds a short "feel" label to keep the preview more intuitive than raw sliders.
- QoL: `Start usual night` now reports one combined status summary instead of stacking separate snackbars for audio outcomes.
- Testing: Added direct `sleep_audio_service` tests for favorite fallback, unavailable assets, premium-locked tracks, and timer preference persistence.
- QoL: Home audio summaries now show the live playing track and remaining timer instead of always showing only the saved favorite.
- QoL: `Start usual night` now reuses already-active wind-down, favorite audio, phone-down, and auto-off states instead of restarting everything blindly.
- QoL: Added one-tap starter routine templates on Home for users who have no wind-down routine configured yet.
- Testing: Added coverage for applying a starter routine template and for showing template shortcuts on Home when the routine is empty.
- UX: Added a dedicated `Usual night setup` screen for bedtime preset, preferred track, sleep timer, and phone-down defaults.
- Testing: Added Home coverage for opening `Usual night setup` and for showing the live playing-track summary in the collapsed audio section.
- UX: Starter routine apply now offers an immediate `Adjust steps` action into a dedicated wind-down routine editor instead of stopping at a passive confirmation.
- UX: `Tonight` now has a stronger complete-state card and clearer “Tonight is fully ready” messaging when all steps are done.
- Testing: Added a `Tonight` regression for the full-completion state so the stronger ready-for-bed presentation stays covered.
- UX: Added a dedicated `Wind-down routine` editor screen and linked it directly from `Settle in`.
- Testing: Added Home coverage for opening the dedicated wind-down routine editor.
- UX: The wind-down step inside `Tonight` now offers `Edit routine` so routine tweaks do not require backing out to Home.
- Testing: Added widget coverage for the dedicated routine-editor route from `Tonight` and for `Start usual night` when wind-down, audio, and phone-down are already active.
- UX: Home now shows a lightweight `Carry into today` card when a mind-unload item is still unresolved from a previous day.
- UX: Home now adds a calmer quiet-state message before the optional supporting sections once tonight is already handled.
- Testing: Added Home coverage for the carry-over card and the quieter done-for-tonight landing state.
