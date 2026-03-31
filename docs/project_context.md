# Project Context

## Overview
NightBuddy is a blue light filter with overlay control, scheduling, and monetization (ads + premium unlock). It helps users prepare for sleep hours before bedtime with a calm, guided night routine.

## Features
- Screen tint overlay with presets and manual tuning.
- Scheduling (off/always/specific times).
- Premium unlock flow (removes ads, unlocks extra warmth/controls).
- Google Mobile Ads for interstitials/banners.
- Quick flashlight toggle (in-app card and notification action).
- Snooze the filter for quick breaks (15/30 minutes) with resume control.
- Settle-in card that blends bedtime timing, quick actions, and routine status.
- Wind-down timeline tied to your scheduled bedtime.
- Wind-down ramp that gradually warms the filter before scheduled start.
- Fade-out ramp that gently eases the filter off after schedule end.
- Sleep tips and a simple manual sleep journal with quality notes.
- Mind unload feature for pre-sleep thought dumping, reminders, worries, and gratitude.
- Environment check feature for practical room-readiness before bed.
- Guided Tonight flow that sequences room setup, mind unload, wind-down, and phone-down steps.
- Guided Tonight flow now emphasizes one active step at a time, with completed steps collapsed below for less visual noise.
- Tonight now visually marks the current focus and auto-anchors the active step when the screen opens.
- Mock phone filter preview for showing how current warmth, opacity, and brightness settings may feel on-device.
- Sleep tips now live on a dedicated screen with expanded, categorized guidance.
- Sleep journal end/edit and morning check-in now use full-screen pages (no sheets).
- Sleep journal quick log now uses a full-page flow (no bottom sheets).
- Mind unload uses a dedicated full-page screen with saved entries and resolved-state tracking.
- Environment check uses a dedicated full-page checklist with nightly persistence.
- Settle-in now links into a dedicated Tonight flow screen for guided progression.
- Home is slimmer: Mind unload and Environment check are accessed through Tonight flow instead of duplicating top-level cards.
- Top-level navigation is now organized into dedicated tabs: `Tonight`, `Journal`, `Audio`, and `Settings`.
- Home/Tonight is now a focused landing screen for the current night instead of a catch-all utility browser.
- Journal, Audio, and Settings each now have their own full screens instead of living behind Home expansion groups.
- Journal is now organized as a real destination with overview, tonight, and history/trends sections.
- Audio is now organized as a real destination with now-playing, quick-start defaults, sleep music, and ambient sections.
- Premium is no longer a primary tab; upgrade/status entry now lives in Settings.
- Premium messaging now uses a more consistent in-app pattern across Home, Audio, Journal, Settings, onboarding, and schedule locking flows.
- Premium policy is now explicit in code: free includes basic filter controls, sleep logging, Rainbound Lullaby, and up to 2 custom presets; premium adds unlimited presets, deeper insights/export, advanced schedules, and extra audio.
- Settings now leans harder into one-time setup with clearer section labels and a direct route into `Usual night defaults`.
- Settings now acts as a setup hub with dedicated subpages for `Display & goals`, `Night prompts`, `Routine & bedtime`, and `Device & privacy`.
- Home filter/status UI is now split into a dedicated widget module so Home keeps moving toward orchestration instead of embedding every tuning/detail component.
- Home support UI is now split into a second dedicated widget module for cross-tab guidance, reminders, schedule summary, premium CTA, and carry-over state.
- Home now uses a dedicated `home_view_data.dart` helper so bedtime progress, audio/tracking summaries, carry-over state, and overlay sync expectations are derived outside the screen widget.
- Settle-in now surfaces a direct `Next:` action summary so users can see the next meaningful bedtime action immediately.
- Settle-in is now lighter on Home: detailed routine checklists stay inside `Tonight`, while Home shows a compact readiness summary and status chips.
- Tune filter now leads with preset identity and a short “feel” description so the preview reads more like an experience than a settings panel.
- Favorite preset support lets users mark a preferred preset and jump back to it quickly from the tuning card.
- Settle-in now changes its primary CTA based on the current bedtime step (`room`, `mind`, `wind-down`, `phone-down`) so users can resume where they left off.
- Quick wind-down now prefers the saved bedtime preset and falls back to the saved favorite preset when appropriate.
- Settle-in now includes a one-tap `Start usual night` action that starts the preferred preset path, favorite track, usual timer, and phone-down flow together.
- Sleep music now remembers the user's usual timer length and highlights it for faster nightly reuse.
- When tonight is already set up, Settle-in quiets down and swaps the timeline block for a calmer "you can put the phone down" message.
- Supporting sections now show compact one-line summaries so Home is easier to scan without opening every section.
- Audio, tracking, and extras now summarize their current state directly in the collapsed section headers.
- Home audio summaries now show live playback state and remaining timer when sleep music is already running.
- Wind-down routine checklist and sleep goal progress insights.
- Sleep score insights, logging streaks, and bedtime/wake averages.
- Bedtime reminders tied to your schedule and morning check-in reminders.
- Caffeine cutoff card based on scheduled bedtime.
- Screen-off goal timer for a short no-phone window before bed.
- One-tap wind-down start (filter + screen-off goal + auto-off timer).
- Blue-light goal card for warm-filter minutes before bed, with a settings slider.
- Morning check-in quick log card for sleep quality and notes.
- Screen-off goal and caffeine cutoff preferences in Settings.
- Bedtime mode options (preset selection, auto screen-off, auto-off timer).
- Wind-down checklist editor in Settings.
- Sunset sync toggle (location-based) for wind-down planning.
- Screen-off goal notifications (start/end).
- Notification schedule card with preview actions.
- Soundscapes with a sleep timer.
- Sleep music card (Rainbound Lullaby) with a track timer, saved favorite shortcut, and placeholders.
- Sleep music now uses a shared audio controller so playback, favorite shortcuts, and `Start usual night` can be triggered outside the card itself.
- `Start usual night` now reports one combined status summary instead of separate audio/error toasts.
- `Start usual night` now behaves more like a resume/update action by reusing active wind-down, audio, phone-down, and auto-off states when they are already running.
- Home now links to a dedicated `Usual night setup` screen for bedtime preset, preferred sleep track, sleep timer, and phone-down defaults.
- Ambient soundscapes placeholders (rain/fan/ocean) marked unavailable.
- Sleep journal CSV export.
- Pause until the next scheduled change.
- Overlay watchdog sync banner when native overlay mismatches app state.
- Multiple custom presets with create/rename/delete.
- High-contrast mode toggle.

## Sounds & Audio
- Ambient soundscapes (rain, fan, ocean) as loopable background noise.
- Sleep music tracks curated for wind-down (longer, non-looped sessions).
- Audio timer with optional fade-out.

## Premium Gating Plan
- Core blue-light filter (manual toggle + basic schedule) stays free.
- Premium unlock removes ads and enables advanced scheduling (weekend vs weekday).
- Premium unlocks premium presets and unlimited custom presets (free: 2 slots).
- Premium unlocks the full soundscape library (free: 2 starter tracks).
- Premium unlocks deeper sleep insights (weekly trends + CSV export).

## Premium Roadmap (Next)
- Limit free custom presets (e.g., 2) and allow unlimited for premium.
- Lock sleep journal export and weekly trends behind premium.
- Add premium-only bedtime suggestions from recent logs.
- Add premium-only extended soundscapes and timers.
- Add optional advanced schedules (split schedule or nap mode).

## Near-Term Roadmap (Next 4-6 Weeks)
- Ship premium gating: limit free presets, lock CSV export + weekly trends, and gate extended soundscapes.
- Expand the soundscape library with 4-6 curated loops and a simple "favorite" toggle.
- Improve insights: add bedtime consistency score and a 7-day trend summary.
- Sunset sync polish: clearer onboarding + a preview of upcoming warm-up window.
- Tighten the paywall flow: clearer value bullets + restore options near the CTA.
- Separate screen-off goal timing from the core schedule (offset-based “X minutes before bedtime”).

## Growth & UX Focus
- Onboarding: add a 3-step setup that sets bedtime, schedule, and a starter preset.
- Notifications: improve opt-in copy and add a gentle "first wind-down" reminder.
- Retention: add a weekly recap card + streak celebration for 3/7/14 nights.
- Store listing: refresh screenshots (Settle-in card, soundscapes, sleep journal).
- Reviews: prompt after 5-7 completed wind-downs or a 3-day streak.

## Recent Improvements
- Refactored Home UI by extracting Sleep Tips and Sleep Audio cards into dedicated widget files.
- Refactored Sleep Journal and Weekly Summary UI into `lib/features/home/widgets/sleep_journal_widgets.dart`.
- Added a persisted Mind Unload feature with a dedicated screen and recent-entry card on Home.
- Added a persisted Environment Check feature with a dedicated screen and progress card on Home.
- Added a dedicated Tonight flow screen that turns key night features into one guided sequence.
- Replaced the abstract filter preview box with a mock phone preview and added a full preview screen.
- Rebuilt top-level app navigation around dedicated `Tonight`, `Journal`, `Audio`, and `Settings` tabs.
- Moved premium entry/status into Settings instead of keeping it as a primary tab.
- Slimmed Home further by removing the old supporting-tools accordion and replacing it with clearer cross-tab guidance.
- Restructured Journal so it feels like one place for sleep history instead of a pile of relocated cards.
- Restructured Audio so current playback, usual defaults, and the library live in one clearer flow.
- Extracted the `Settle in` / tonight-plan implementation into its own widget file so Home keeps acting more like an orchestrator than a monolith.
- Reframed Settings around setup-oriented categories (`Quick access`, `Night prompts`, `Night goals`, `Routine setup`, `Bedtime automation`, `Device & accessibility`, `Data & privacy`).
- Reworked Settings further into a true navigation hub so those setup categories now open dedicated pages instead of living in one long scroll.
- Extracted the remaining Home filter/status cluster into `lib/features/home/widgets/home_filter_sections.dart` so overlay banners, filter status, presets, sliders, and preview are no longer embedded in `home_screen.dart`.
- Extracted the remaining Home support cluster into `lib/features/home/widgets/home_support_sections.dart` so schedule/reminder cards, guidance, carry-over, premium CTA, and ad area are no longer embedded in `home_screen.dart`.
- Moved Home's remaining derived-state calculations into `lib/features/home/home_view_data.dart` so `home_screen.dart` is closer to composition and navigation instead of inline summary logic.
- Simplified the Settle-in action row by moving schedule/defaults/routine links under a single `Adjust setup` menu so bedtime actions stay visually dominant.
- Standardized premium upsell/lock UI with shared helpers in `lib/widgets/premium_ui.dart`.
- Centralized premium plan constants in `lib/constants/premium_policy.dart` so free vs premium rules stay aligned across UI and gating logic.
- Reworked Tonight into a more sequential routine view with a highlighted current step, progress summary, and completed-step recap.
- Added active-step focus treatment in Tonight so the current step is visually anchored instead of only reordered.
- Tonight now shows an `After this` preview so the user can see the next step coming without scanning the whole routine.
- Added a shared sleep-audio controller and wired Home into it for broader playback actions.
- Added direct unit coverage for the shared audio controller, including favorite fallback, unavailable asset handling, premium locking, and timer persistence.
- Added starter wind-down routine templates so users with an empty routine can seed one from Home in one tap.
- Added a dedicated `Usual night setup` screen so recurring bedtime defaults are configured in one place instead of across multiple cards/settings.
- Starter routine templates now offer an immediate `Adjust steps` follow-up into a dedicated wind-down routine editor so the routine can be personalized right after apply.
- Home now links directly to a dedicated wind-down routine editor from `Settle in`, rather than sending routine editing through broad Settings.
- `Tonight` now also links directly to the dedicated wind-down routine editor from the wind-down step when a routine exists.
- Home now surfaces unresolved mind-unload items from earlier nights in a lightweight `Carry into today` card.
- When tonight is already handled, the supporting area now adds a calmer quiet-state message before the optional sections.
- Simplified Settle-in on Home by removing the embedded routine checklist and replacing it with a calmer progress summary.
- Improved Tune filter hierarchy with preset labels, short feel descriptions, and preview-first guidance.
- Added saved favorites for presets and sleep music so repeated night actions take fewer taps.
- Made the primary bedtime CTA resume the current step instead of always using a generic `Continue tonight` label.
- Added remembered sleep timer preferences so common audio timers take fewer taps.
- Added compact collapsed summaries for audio, tracking, and extras to reduce Home scan effort.
- Improved supporting-section subtitles so users can scan Home without opening every expansion tile.
- Added a regression test for the dedicated Sleep History screen flow.
- Added Insights v1 with bedtime consistency scoring and 7-day trend summaries.
- Persisted screen-off goal state and added default duration settings.
- Added caffeine cutoff and blue-light goal sliders with quick presets.
- Added bedtime mode options (preset selection + auto screen-off).
- Added wind-down checklist editor in Settings.
- Added location-based sunset sync, screen-off notifications, and soundscapes.
- Added CSV export for sleep journal logs.
- Added bedtime mode auto-off timer and reorderable checklist.
- Replaced separate wind-down planner/routine with a unified Settle-in card.
- Moved sleep music and ambient soundscapes into the main home flow.
- Expanded Sleep tips and moved them to a full-screen page.
- Converted sleep journal end/edit + morning check-in to full-screen pages.
- Converted remaining bottom-sheet flows to dedicated pages (sleep journal, tips, legal).
- Migrated the sleep journal quick log into a full-screen page.
- Rainbound Lullaby playback restored (asset bytes + flexible path lookup).

## Dev Notes
- Audio assets use full paths from the project root (e.g., `assets/sounds/SoundScapes/Rain.aac`).
- Ensure asset folders are listed under `flutter: assets:` in `pubspec.yaml`.
- After changing assets, run `flutter pub get` and hot restart (or `flutter clean` if needed).
- Sleep music playback attempts both `assets/...` and non-prefixed asset paths.
- Shared audio controller behavior is now directly tested without the plugin by overriding the player factory and asset loader providers.
- Home widget coverage now includes the dedicated `Usual night setup` route and the live playing-track summary in the collapsed audio section.
- Home/Tonight widget coverage now includes the stronger completed-state presentation once the full bedtime routine is already done.
- Home/Tonight widget coverage now includes the dedicated routine-editor route from `Tonight` and the `Start usual night` summary for already-active states.
- Home widget coverage now includes the morning mind-unload carry-over card and the quieter done-for-tonight state on the landing screen.
- Root-shell and section-screen coverage now includes the new Journal/Audio destination structure.
- Widget coverage now includes the Settings hub structure and the direct `Usual night defaults` route.
- Track changes and fixes in `docs/dev_log.md`.
- `home_screen.dart` still needs further decomposition, but Sleep Journal/Weekly Summary are now split out as a first major pass.
- `Settle in` now lives in `lib/features/home/widgets/tonight_plan_card.dart` instead of being embedded directly in `home_screen.dart`.
- Home filter/status widgets now live in `lib/features/home/widgets/home_filter_sections.dart`.
- Home support widgets now live in `lib/features/home/widgets/home_support_sections.dart`.
- Shared premium cards and lock snackbars now live in `lib/widgets/premium_ui.dart`.
- Mind unload entries persist in app state and are capped to keep storage bounded.
- Environment checklist persists per night and resets cleanly for the next day.
- Tonight flow currently orchestrates existing features rather than duplicating their logic.
- Home navigation is being reduced by routing denser sub-features through dedicated screens instead of stacking every card on the landing page.
- The old Home-only supporting-tools grouping has been retired in favor of proper top-level screens.
- `flutter test` currently passes end to end after updating Home navigation/widget tests for the grouped layout.
- Home and Tonight widget regressions are covered for the sequential routine layout and full-page history flow.
- Added notification previews and upcoming reminder visibility.
- Added overlay watchdog sync and guidance banner.
- Added multi custom presets and management UI.
- Added high-contrast accessibility toggle.
- Added weekly summary expansion with more insights and sharing details.

## Overlay Control Model
- Single source of truth: `filterEnabled`.
- Schedule and notification are input events only.
- App start/resume reconciles `filterEnabled` with native overlay state.
- Details: `docs/overlay_architecture.md`, `docs/scheduling_model.md`,
  `docs/notification_contract.md`.

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
- Current app version: `2.0.0+7` (see `pubspec.yaml` and `CHANGELOG.md`).
- We follow semver for releases and increment the build number for store uploads.

## Core Principles
- Single source of truth for overlay state (`filterEnabled`).
- Schedule and notifications are input events only.
- Manual toggles are always allowed outside of explicit schedule events.
- Sync with native overlay state on app start/resume.

## Feature Ideas (Night Routine)
- Adaptive schedule: bedtime suggestions based on recent logs, with gentle nudges.
- Sunset sync: automatic warm-up tied to local sunset, plus lighting tips.
- Sleep prep checklist: customizable routine steps with streaks and quick taps.
- Morning check-in: quick mood/energy/quality rating for better insights.
- Sleep tips carousel: personalized tips based on recent habits.
- Alarm handoff: optional wind-down start based on alarm time.
- Data export: CSV for sleep journal entries and weekly summaries.
- Wind-down checklist reordering and templates.
- Screen-off goal notifications to start/end the no-phone window.
- Bedtime mode extras: optional auto-snooze and preset preview.
- Mind unload card: quick thoughts/worries dump saved as dedicated pre-sleep notes.
- Mind unload follow-up: allow converting entries into tomorrow tasks or journal tags.
- Environment check card: room temp, lights, and noise checklist before bed.
- Environment check card: lights, comfort, alarm, and bedside essentials before bed.
- Gentle countdown card: bedtime countdown with a short breathe prompt.
