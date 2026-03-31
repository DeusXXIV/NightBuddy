import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../constants/app_links.dart';
import '../../models/filter_models.dart';
import '../../services/ads_service.dart';
import '../../services/log_service.dart';
import '../../services/overlay_service.dart';
import '../../state/app_notifier.dart';
import '../../state/app_state.dart';
import '../../widgets/premium_ui.dart';
import '../../services/sleep_audio_service.dart';
import '../premium/premium_screen.dart';
import '../schedule/schedule_screen.dart';
import 'home_view_data.dart';
import 'widgets/home_filter_sections.dart';
import 'widgets/home_support_sections.dart';
import 'widgets/tonight_plan_card.dart';
import 'widgets/tonight_flow_screen.dart';
import 'widgets/usual_night_setup_screen.dart';
import 'widgets/wind_down_routine_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    return appState.when(
      data: (state) => _HomeView(state: state),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

final overlayDebugInfoProvider = FutureProvider.autoDispose<HomeOverlayDebugInfo>((
  ref,
) async {
  final service = ref.read(overlayServiceProvider);
  final hasPermission = await service.hasPermission();
  final isEnabled = await service.isOverlayEnabled();
  return HomeOverlayDebugInfo(
    hasPermission: hasPermission,
    isEnabled: isEnabled,
  );
});

final overlayPermissionProvider = FutureProvider.autoDispose<bool>((ref) async {
  final service = ref.read(overlayServiceProvider);
  return service.hasPermission();
});

final overlayStatusProvider = FutureProvider.autoDispose<bool?>((ref) async {
  final service = ref.read(overlayServiceProvider);
  return service.isOverlayEnabled();
});

bool _reviewPromptShowing = false;

class _HomeView extends ConsumerWidget {
  const _HomeView({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appStateProvider.notifier);
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(minutes: 1), (tick) => tick),
      builder: (context, _) => _buildCard(context, ref, notifier),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    AppStateNotifier notifier,
  ) {
    _maybeShowReviewPrompt(context, ref, state);
    final now = DateTime.now();
    final audio = ref.watch(sleepAudioControllerProvider);
    final logService = ref.read(logServiceProvider);
    final overlayPermission = ref.watch(overlayPermissionProvider);
    final overlayStatus = ref.watch(overlayStatusProvider);
    final hasOverlayPermission = overlayPermission.maybeWhen(
      data: (value) => value,
      orElse: () => true,
    );
    final nativeOverlayEnabled = overlayStatus.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final viewData = buildHomeViewData(state: state, audio: audio, now: now);
    final showOverlayMismatch =
        hasOverlayPermission &&
        nativeOverlayEnabled != null &&
        nativeOverlayEnabled != viewData.shouldEnableOverlay;
    Future<void> openSchedule() async {
      final navigator = Navigator.of(context);
      if (!state.isPremium) {
        await ref.read(adsServiceProvider).showInterstitialIfAvailable();
      }
      navigator.push(MaterialPageRoute(builder: (_) => const ScheduleScreen()));
    }

    Future<bool> ensureOverlayPermission() async {
      final overlayService = ref.read(overlayServiceProvider);
      final hasPermission = await overlayService.hasPermission();
      if (hasPermission) return true;
      if (!context.mounted) return false;
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Allow overlay permission'),
          content: const Text(
            'NightBuddy needs permission to draw over other apps to tint the screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );
      if (shouldOpen != true) {
        await logService.logEvent(
          type: 'overlay_permission_skipped',
          message: 'User declined overlay permission prompt.',
        );
        return false;
      }
      await overlayService.requestPermission();
      final granted = await overlayService.hasPermission();
      if (!granted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Overlay permission required to enable'),
          ),
        );
        await logService.logEvent(
          type: 'overlay_permission_denied',
          message: 'Overlay permission still not granted after request.',
        );
      }
      ref.invalidate(overlayPermissionProvider);
      return granted;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('NightBuddy'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Protect your eyes at night',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (!hasOverlayPermission) ...[
              HomeOverlayPermissionBanner(
                onEnable: () async {
                  final service = ref.read(overlayServiceProvider);
                  await service.requestPermission();
                  final granted = await service.hasPermission();
                  if (!granted) {
                    await logService.logEvent(
                      type: 'overlay_permission_denied',
                      message: 'Overlay permission request denied from banner.',
                    );
                  }
                  ref.invalidate(overlayPermissionProvider);
                },
              ),
              const SizedBox(height: 12),
            ],
            if (showOverlayMismatch) ...[
              HomeOverlayWatchdogBanner(
                shouldEnable: viewData.shouldEnableOverlay,
                onSync: () async {
                  await notifier.syncNow();
                  ref.invalidate(overlayStatusProvider);
                },
              ),
              const SizedBox(height: 12),
            ],
            HomeStatusCard(
              state: state,
              isActive: viewData.isFilterActive,
              snoozedUntil: viewData.snoozedUntil,
              now: now,
              nextChange: state.nextScheduleChange(now),
              onToggle: (value) async {
                if (value) {
                  final granted = await ensureOverlayPermission();
                  if (!granted) return;
                }

                final ok = await notifier.toggleOverlay(value);
                if (!ok) {
                  final hasPermission = await ref
                      .read(overlayServiceProvider)
                      .hasPermission();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        hasPermission
                            ? 'Unable to enable the filter right now'
                            : 'Grant overlay permission to enable the filter',
                      ),
                    ),
                  );
                  await logService.logEvent(
                    type: 'overlay_toggle_failed',
                    message: 'Overlay toggle failed from home screen.',
                    details: {
                      'targetEnabled': value,
                      'hasPermission': hasPermission,
                    },
                  );
                }
              },
              onSnooze: (duration) =>
                  ref.read(appStateProvider.notifier).snoozeFor(duration),
              onResume: () => ref.read(appStateProvider.notifier).clearSnooze(),
              onPauseUntilNext: () async {
                final ok = await ref
                    .read(appStateProvider.notifier)
                    .snoozeUntilNextChange();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No upcoming schedule change to pause until',
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            HomeSectionHeader(
              title: 'Tune tonight',
              subtitle:
                  'Adjust your filter and preview the look before you settle in.',
            ),
            if (kDebugMode && state.showDebugTools) ...[
              const SizedBox(height: 12),
              HomeOverlayDebugCard(info: ref.watch(overlayDebugInfoProvider)),
            ],
            const SizedBox(height: 12),
            HomePresetCarousel(
              state: state,
              onSelectPreset: (preset) async {
                final success = await notifier.selectPreset(preset.id);
                if (!success && context.mounted) {
                  _showPremiumSnack(context);
                  _openPremium(context);
                }
              },
            ),
            const SizedBox(height: 12),
            HomeSlidersSection(
              state: state,
              onSelectPreset: (presetId) async {
                final success = await notifier.selectPreset(presetId);
                if (!success && context.mounted) {
                  _showPremiumSnack(context);
                  _openPremium(context);
                }
              },
              onToggleFavoritePreset: notifier.setFavoritePreset,
              onChanged: (values) async {
                if (state.activePreset.isPremium && !state.isPremium) {
                  _showPremiumSnack(context);
                  _openPremium(context);
                } else {
                  final ok = await notifier.updateActivePreset(
                    temperature: values.temperature,
                    opacity: values.opacity,
                    brightness: values.brightness,
                  );
                  if (!ok && context.mounted) {
                    _showPremiumSnack(context);
                    _openPremium(context);
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            HomeScheduleCard(
              state: state,
              onOpen: () async {
                if (!state.isPremium) {
                  await ref
                      .read(adsServiceProvider)
                      .showInterstitialIfAvailable();
                }
              },
            ),
            const SizedBox(height: 12),
            HomeRemindersCard(
              state: state,
              onSnooze: () =>
                  notifier.snoozeRemindersFor(const Duration(days: 1)),
              onResume: notifier.clearReminderSnooze,
            ),
            if (state.schedule.mode == FilterMode.scheduled)
              const SizedBox(height: 12),
            if (state.schedule.mode == FilterMode.scheduled)
              HomeScheduleTimelineCard(state: state),
            const SizedBox(height: 12),
            const HomeSectionHeader(
              title: 'Tonight',
              subtitle:
                  'One guided place for the actions that matter before sleep.',
            ),
            const SizedBox(height: 12),
            TonightPlanCard(
              state: state,
              onOpenSchedule: openSchedule,
              onApplyRoutineTemplate: (labels) async {
                await notifier.applyWindDownTemplate(labels);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Starter routine added for tonight'),
                      action: SnackBarAction(
                        label: 'Adjust steps',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WindDownRoutineScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }
              },
              onOpenUsualNightSetup: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UsualNightSetupScreen(),
                  ),
                );
              },
              onOpenRoutineEditor: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WindDownRoutineScreen(),
                  ),
                );
              },
              onOpenTonightFlow: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TonightFlowScreen()),
                );
              },
              onStartWindDown: () async {
                final granted = await ensureOverlayPermission();
                if (!granted) return;
                final presetId =
                    state.bedtimeModePresetId ?? state.favoritePresetId;
                if (presetId != null && presetId != state.activePresetId) {
                  final okPreset = await notifier.selectPreset(presetId);
                  if (!okPreset && context.mounted) {
                    _showPremiumSnack(context);
                    _openPremium(context);
                    return;
                  }
                }
                final ok = await notifier.toggleOverlay(true);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to start wind-down right now'),
                    ),
                  );
                  return;
                }
                if (state.bedtimeModeStartScreenOff) {
                  await notifier.startScreenOffGoal(
                    Duration(minutes: state.screenOffGoalMinutes),
                  );
                }
                if (state.bedtimeModeAutoOffMinutes > 0) {
                  await notifier.startBedtimeModeAutoOff(
                    Duration(minutes: state.bedtimeModeAutoOffMinutes),
                  );
                }
              },
              onStartUsualNight: () async {
                final granted = await ensureOverlayPermission();
                if (!granted) return;
                final updates = <String>[];
                final now = DateTime.now();
                final presetId =
                    state.bedtimeModePresetId ?? state.favoritePresetId;
                if (presetId != null && presetId != state.activePresetId) {
                  final okPreset = await notifier.selectPreset(presetId);
                  if (!okPreset && context.mounted) {
                    _showPremiumSnack(context);
                    _openPremium(context);
                    return;
                  }
                  updates.add('preset ready');
                }
                final windDownAlreadyActive = state.isFilterActive(now);
                if (windDownAlreadyActive) {
                  updates.add('wind-down already active');
                } else {
                  final ok = await notifier.toggleOverlay(true);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unable to start your usual night right now',
                        ),
                      ),
                    );
                    return;
                  }
                  updates.add('wind-down active');
                }
                final audio = ref.read(sleepAudioControllerProvider);
                final favoriteTrackId =
                    state.favoriteSleepTrackId ?? sleepTrackOptions.first.id;
                final sameTrackPlaying =
                    audio.isPlaying && audio.activeTrackId == favoriteTrackId;
                if (sameTrackPlaying) {
                  if (audio.endTime == null || audio.endTime!.isBefore(now)) {
                    await audio.startTimer(
                      Duration(minutes: state.preferredSleepTimerMinutes),
                    );
                    updates.add(
                      'music continued for ${state.preferredSleepTimerMinutes}m',
                    );
                  } else {
                    updates.add('favorite music already playing');
                  }
                } else {
                  final audioResult = await audio.playFavoriteTrack();
                  switch (audioResult) {
                    case SleepAudioResult.playing:
                      await audio.startTimer(
                        Duration(minutes: state.preferredSleepTimerMinutes),
                      );
                      updates.add(
                        'music for ${state.preferredSleepTimerMinutes}m',
                      );
                    case SleepAudioResult.premiumLocked:
                      updates.add('favorite music locked');
                    case SleepAudioResult.unavailable:
                      updates.add('music skipped');
                  }
                }
                final phoneDownActive =
                    state.screenOffUntil != null &&
                    state.screenOffUntil!.isAfter(now);
                if (phoneDownActive) {
                  updates.add('phone-down already active');
                } else {
                  await notifier.startScreenOffGoal(
                    Duration(minutes: state.screenOffGoalMinutes),
                  );
                  updates.add('phone-down started');
                }
                if (state.bedtimeModeAutoOffMinutes > 0) {
                  final autoOffActive =
                      state.bedtimeModeAutoOffUntil != null &&
                      state.bedtimeModeAutoOffUntil!.isAfter(now);
                  if (autoOffActive) {
                    updates.add('auto-off already running');
                  } else {
                    await notifier.startBedtimeModeAutoOff(
                      Duration(minutes: state.bedtimeModeAutoOffMinutes),
                    );
                    updates.add(
                      'auto-off in ${state.bedtimeModeAutoOffMinutes}m',
                    );
                  }
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Usual night started: ${updates.join(', ')}',
                      ),
                    ),
                  );
                }
              },
            ),
            if (viewData.carryOverEntry != null) ...[
              const SizedBox(height: 12),
              HomeMindUnloadCarryOverCard(entry: viewData.carryOverEntry!),
            ],
            const SizedBox(height: 12),
            HomeSectionHeader(
              title: 'Other tabs',
              subtitle: viewData.isReadyForTonight
                  ? 'You are set for tonight. Open these only if you want to review or adjust something.'
                  : 'Use these tabs for sleep history, audio, and settings.',
            ),
            const SizedBox(height: 12),
            HomeNavigationGuideCard(
              audioSummary: viewData.liveAudioSummary,
              trackingSummary: viewData.trackingSummary,
              extrasSummary: viewData.extrasSummary,
              isReadyForTonight: viewData.isReadyForTonight,
            ),
            if (!state.isPremium)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: HomePremiumCta(onTap: () => _openPremium(context)),
              ),
            if (!state.isPremium)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: HomeAdArea(),
              ),
          ],
        ),
      ),
    );
  }

  void _showPremiumSnack(BuildContext context) {
    showPremiumLockedSnackBar(context, featureName: 'This feature');
  }

  void _openPremium(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
  }
}

void _maybeShowReviewPrompt(
  BuildContext context,
  WidgetRef ref,
  AppState state,
) {
  if (!state.reviewPromptPending || _reviewPromptShowing) return;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!context.mounted) return;
    if (_reviewPromptShowing) return;
    _reviewPromptShowing = true;
    try {
      final shouldRate = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Enjoying NightBuddy?'),
          content: const Text(
            'If the wind-down routine is helping, a quick rating would mean a lot.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Rate now'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      if (shouldRate == true) {
        await _openStoreReview(context);
      }
      await ref.read(appStateProvider.notifier).recordReviewPromptHandled();
    } finally {
      _reviewPromptShowing = false;
    }
  });
}

Future<void> _openStoreReview(BuildContext context) async {
  final market = 'market://details?id=$kAndroidPackageId';
  final web =
      'https://play.google.com/store/apps/details?id=$kAndroidPackageId';
  if (await canLaunchUrlString(market)) {
    await launchUrlString(market, mode: LaunchMode.externalApplication);
    return;
  }
  if (await canLaunchUrlString(web)) {
    await launchUrlString(web, mode: LaunchMode.externalApplication);
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Unable to open Play Store')));
}
