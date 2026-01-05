import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/filter_models.dart';
import '../../models/sleep_journal.dart';
import '../../services/ads_service.dart';
import '../../services/log_service.dart';
import '../../services/overlay_service.dart';
import '../../state/app_notifier.dart';
import '../../state/app_state.dart';
import '../../widgets/ads_banner.dart';
import '../../widgets/filter_preview_overlay.dart';
import '../../widgets/preset_chip.dart';
import '../../utils/sleep_metrics.dart';
import '../premium/premium_screen.dart';
import '../schedule/schedule_screen.dart';

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

final overlayDebugInfoProvider =
    FutureProvider.autoDispose<_OverlayDebugInfo>((ref) async {
  final service = ref.read(overlayServiceProvider);
  final hasPermission = await service.hasPermission();
  final isEnabled = await service.isOverlayEnabled();
  return _OverlayDebugInfo(
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
    final now = DateTime.now();
    final isActive = state.isFilterActive(now);
    final snoozedUntil = state.snoozeUntil;
    final sleepJournalActiveStart = state.sleepJournalActiveStart;
    final sleepJournalEntries = state.sleepJournalEntries;
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
    final shouldEnable = state.filterEnabled && !state.isSnoozed(now);
    final showOverlayMismatch =
        hasOverlayPermission &&
            nativeOverlayEnabled != null &&
            nativeOverlayEnabled != shouldEnable;
    Future<void> openSchedule() async {
      final navigator = Navigator.of(context);
      if (!state.isPremium) {
        await ref.read(adsServiceProvider).showInterstitialIfAvailable();
      }
      navigator.push(
        MaterialPageRoute(builder: (_) => const ScheduleScreen()),
      );
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
              _OverlayPermissionBanner(
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
              _OverlayWatchdogBanner(
                shouldEnable: shouldEnable,
                onSync: () async {
                  await notifier.syncNow();
                  ref.invalidate(overlayStatusProvider);
                },
              ),
              const SizedBox(height: 12),
            ],
            _StatusCard(
              state: state,
              isActive: isActive,
              snoozedUntil: snoozedUntil,
              now: now,
              nextChange: state.nextScheduleChange(now),
              onToggle: (value) async {
                if (value) {
                  final granted = await ensureOverlayPermission();
                  if (!granted) return;
                }

                final ok = await notifier.toggleOverlay(value);
                if (!ok) {
                  final hasPermission =
                      await ref.read(overlayServiceProvider).hasPermission();
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
                onResume: () =>
                    ref.read(appStateProvider.notifier).clearSnooze(),
              onPauseUntilNext: () async {
                final ok = await ref
                    .read(appStateProvider.notifier)
                    .snoozeUntilNextChange();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No upcoming schedule change to pause until'),
                    ),
                  );
                }
              },
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              const _OverlayDebugCard(),
            ],
            const SizedBox(height: 12),
            _BedtimeModeCard(
              isActive: isActive,
              presetLabel: state.bedtimeModePresetId == null
                  ? state.activePreset.name
                  : state.presets
                      .firstWhere(
                        (preset) => preset.id == state.bedtimeModePresetId,
                        orElse: () => state.activePreset,
                      )
                      .name,
              onStart: () async {
                final granted = await ensureOverlayPermission();
                if (!granted) return;
                final presetId = state.bedtimeModePresetId;
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
                      content: Text('Unable to start bedtime mode right now'),
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
            ),
            const SizedBox(height: 12),
            _PresetCarousel(
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
            _FlashlightCard(state: state),
            const SizedBox(height: 12),
            _SlidersSection(
              state: state,
              onChanged: (values) {
                if (state.activePreset.isPremium && !state.isPremium) {
                  _showPremiumSnack(context);
                  _openPremium(context);
                } else {
                  notifier.updateActivePreset(
                    temperature: values.temperature,
                    opacity: values.opacity,
                    brightness: values.brightness,
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            _ScheduleCard(
              state: state,
              onOpen: () async {
                if (!state.isPremium) {
                  await ref
                      .read(adsServiceProvider)
                      .showInterstitialIfAvailable();
                }
              },
            ),
            if (state.schedule.mode == FilterMode.scheduled)
              const SizedBox(height: 12),
            if (state.schedule.mode == FilterMode.scheduled)
              _ScheduleTimelineCard(state: state),
            const SizedBox(height: 12),
            _WindDownPlannerCard(
              state: state,
              onOpenSchedule: openSchedule,
            ),
            const SizedBox(height: 12),
            _WeeklySummaryCard(
              entries: sleepJournalEntries,
              sleepGoalMinutes: state.sleepGoalMinutes,
              onShare: () => _shareWeeklySummary(
                context,
                sleepJournalEntries,
                state.sleepGoalMinutes,
              ),
            ),
            const SizedBox(height: 12),
            _SleepJournalCard(
              activeStart: sleepJournalActiveStart,
              entries: sleepJournalEntries,
              sleepGoalMinutes: state.sleepGoalMinutes,
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('More tools'),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                _ScreenOffGoalCard(state: state),
                const SizedBox(height: 12),
                _BlueLightGoalCard(state: state, onOpenSchedule: openSchedule),
                const SizedBox(height: 12),
                _CaffeineCutoffCard(
                  state: state,
                  onOpenSchedule: openSchedule,
                ),
                const SizedBox(height: 12),
                _WindDownRoutineCard(
                  state: state,
                  onToggle: (id, value) =>
                      notifier.toggleWindDownChecklistItem(id, value),
                  onReset: notifier.resetWindDownChecklist,
                ),
                const SizedBox(height: 12),
                _MorningCheckInCard(state: state),
                const SizedBox(height: 12),
                _FlashlightCard(state: state),
                const SizedBox(height: 12),
                const _SoundscapesCard(),
                const SizedBox(height: 12),
                const _SleepTipsCard(),
                const SizedBox(height: 4),
              ],
            ),
            if (!state.isPremium)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _PremiumCta(onTap: () => _openPremium(context)),
              ),
            if (!state.isPremium)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: _AdArea(),
              ),
          ],
        ),
      ),
    );
  }

  void _showPremiumSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Premium preset - upgrade to unlock'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openPremium(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
  }
}

class _OverlayPermissionBanner extends StatelessWidget {
  const _OverlayPermissionBanner({required this.onEnable});

  final Future<void> Function() onEnable;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers_outlined),
                const SizedBox(width: 8),
                Text(
                  'Enable overlay permission',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Required to tint your screen in other apps.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await onEnable();
                },
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('Enable'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayWatchdogBanner extends StatelessWidget {
  const _OverlayWatchdogBanner({
    required this.shouldEnable,
    required this.onSync,
  });

  final bool shouldEnable;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    final title = shouldEnable
        ? 'Overlay paused by system'
        : 'Overlay still running';
    final description = shouldEnable
        ? 'Tap to retry syncing the filter overlay.'
        : 'Tap to stop the overlay and match your current setting.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_problem_outlined),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await onSync();
                },
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sync now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.state,
    required this.isActive,
    required this.snoozedUntil,
    required this.now,
    required this.nextChange,
    required this.onToggle,
    required this.onSnooze,
    required this.onResume,
    required this.onPauseUntilNext,
  });

  final AppState state;
  final bool isActive;
  final DateTime? snoozedUntil;
  final DateTime now;
  final DateTime? nextChange;
  final ValueChanged<bool> onToggle;
  final ValueChanged<Duration> onSnooze;
  final VoidCallback onResume;
  final Future<void> Function() onPauseUntilNext;

  @override
  Widget build(BuildContext context) {
    final isSnoozed = state.isSnoozed(now);
    final scheduledPreset = state.scheduledPreset;
    final activePreset = state.activePreset;
    final showManualPreset =
        state.schedule.mode == FilterMode.scheduled &&
            scheduledPreset.id != activePreset.id;
    final statusLabel = isSnoozed
        ? 'Filter is snoozed'
        : (isActive ? 'Filter is ON' : 'Filter is OFF');
    final presetLabel = state.schedule.mode == FilterMode.scheduled
        ? 'Scheduled preset: ${scheduledPreset.name}'
        : 'Preset: ${activePreset.name}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        presetLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (showManualPreset)
                        Text(
                          'Manual preset: ${activePreset.name}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: _mutedColor(context)),
                        ),
                      Text(
                        _scheduleLabel(state.schedule),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: _mutedColor(context)),
                      ),
                      if (state.schedule.mode == FilterMode.scheduled &&
                          (state.schedule.windDownMinutes > 0 ||
                              state.schedule.fadeOutMinutes > 0))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _rampLabel(),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: (state.isWindDownActive(now) ||
                                          state.isFadeOutActive(now))
                                      ? Colors.amber
                                      : _mutedColor(context),
                                ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _nextChangeLabel(),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: _mutedColor(context)),
                        ),
                      ),
                      if (snoozedUntil != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Snoozed until ${_formatDateTime(snoozedUntil!)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.amber),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(value: state.filterEnabled, onChanged: onToggle),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.snooze, size: 18),
                  label: const Text('Pause 15m'),
                  onPressed: () => onSnooze(const Duration(minutes: 15)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.snooze, size: 18),
                  label: const Text('Pause 30m'),
                  onPressed: () => onSnooze(const Duration(minutes: 30)),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.timelapse, size: 18),
                  label: Text(
                    nextChange == null
                        ? 'Pause until next'
                        : 'Pause until ${_formatDateTime(nextChange!)}',
                  ),
                  onPressed: nextChange == null ? null : () async {
                    await onPauseUntilNext();
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Resume now'),
                  onPressed: snoozedUntil != null ? onResume : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _scheduleLabel(ScheduleConfig schedule) {
    switch (schedule.mode) {
      case FilterMode.off:
        return 'Scheduled: Off';
      case FilterMode.alwaysOn:
        return 'Scheduled: Always on';
      case FilterMode.scheduled:
        final start = _formatTime(schedule.startTime);
        final end = _formatTime(schedule.endTime);
        return 'Scheduled: $start - $end';
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _formatDateTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _rampLabel() {
    if (state.isWindDownActive(now)) {
      final progress = (state.windDownProgress(now) * 100).round();
      return 'Warming up: $progress%';
    }
    if (state.isFadeOutActive(now)) {
      final progress = (state.fadeOutProgress(now) * 100).round();
      return 'Cooling down: $progress%';
    }
    final windDownMinutes = state.schedule.windDownMinutes;
    final fadeOutMinutes = state.schedule.fadeOutMinutes;
    if (windDownMinutes > 0 && fadeOutMinutes > 0) {
      return 'Wind-down ${windDownMinutes}m / Fade-out ${fadeOutMinutes}m';
    }
    if (windDownMinutes > 0) {
      return 'Wind-down: $windDownMinutes min before start';
    }
    if (fadeOutMinutes > 0) {
      return 'Fade-out: $fadeOutMinutes min after end';
    }
    return '';
  }

  String _nextChangeLabel() {
    final next = state.nextScheduleChange(now);
    if (!state.filterEnabled) {
      if (next != null && state.schedule.mode == FilterMode.scheduled) {
        return 'Manual off - next at ${_formatDateTime(next)}';
      }
      return 'Manual off';
    }
    if (next == null) {
      switch (state.schedule.mode) {
        case FilterMode.off:
          return 'Scheduled: Off';
        case FilterMode.alwaysOn:
          return 'Always on';
        case FilterMode.scheduled:
          return 'Following schedule';
      }
    }
    final formatted = _formatDateTime(next);
    final active = state.isFilterActive(now);
    return active ? 'On until $formatted' : 'Starts at $formatted';
  }
}

class _BedtimeModeCard extends StatelessWidget {
  const _BedtimeModeCard({
    required this.isActive,
    required this.presetLabel,
    required this.onStart,
  });

  final bool isActive;
  final String presetLabel;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bedtime_outlined),
                const SizedBox(width: 8),
                Text(
                  'Bedtime mode',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enable your filter and settle in.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 6),
            Text(
              'Preset: $presetLabel',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: isActive ? null : onStart,
                child: Text(isActive ? 'Active' : 'Start now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepTipsCard extends StatelessWidget {
  const _SleepTipsCard();

  static const _tips = [
    'Keep a consistent bedtime and wake time.',
    'Dim lights and screens 60 minutes before bed.',
    'Avoid caffeine late in the day.',
    'Keep the room cool, dark, and quiet.',
    'Get morning light exposure to anchor your rhythm.',
  ];

  @override
  Widget build(BuildContext context) {
    final previewTips = _tips.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.nightlight_outlined),
                const SizedBox(width: 8),
                Text(
                  'Sleep tips',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...previewTips.map((tip) => _TipRow(text: tip)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showAllTips(context),
                child: const Text('More tips'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllTips(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.nightlight_outlined),
                  const SizedBox(width: 8),
                  Text(
                    'Sleep tips',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _tips.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(_tips[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 6),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _WindDownRoutineCard extends StatelessWidget {
  const _WindDownRoutineCard({
    required this.state,
    required this.onToggle,
    required this.onReset,
  });

  final AppState state;
  final void Function(String id, bool value) onToggle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final checklist = state.windDownChecklistFor(now);
    final items = state.windDownItems;
    final completedCount =
        items.where((item) => checklist[item.id] == true).length;
    final totalCount = items.length;
    final allDone = completedCount == totalCount && totalCount > 0;
    final summary = allDone
        ? 'All done for tonight.'
        : 'Completed $completedCount of $totalCount tonight.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.spa_outlined),
                const SizedBox(width: 8),
                Text(
                  'Wind-down routine',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summary,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Resets nightly so you can check in again tomorrow.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(
                'Add your routine in Settings.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            ...items.map((item) {
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(item.label),
                value: checklist[item.id] == true,
                onChanged: (value) {
                  if (value == null) return;
                  onToggle(item.id, value);
                },
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: completedCount == 0 ? null : onReset,
                child: const Text('Reset for tonight'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({
    required this.entries,
    required this.sleepGoalMinutes,
    required this.onShare,
  });

  final List<SleepJournalEntry> entries;
  final int sleepGoalMinutes;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final summary = _calculateWeeklySummary(entries, now, sleepGoalMinutes);
    final goalDuration = Duration(minutes: sleepGoalMinutes);
    final averageDuration = summary.averageDuration;
    final averageQuality = summary.averageQuality;
    final streak = summary.streak;
    final consistency = summary.bedtimeConsistency;
    final loggedNights = summary.loggedNights;
    final goalHitCount = summary.goalHitCount;
    final recentEntries = summary.recentEntries;
    final averageBedtimeMinutes = summary.averageBedtimeMinutes;
    final averageWakeMinutes = summary.averageWakeMinutes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined),
                const SizedBox(width: 8),
                Text(
                  'Weekly summary',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: entries.isEmpty ? null : onShare,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Text(
                'Log a few nights to see your weekly summary.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              )
            else ...[
              Text(
                'Avg sleep: ${averageDuration == null ? '--' : _formatDuration(averageDuration)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                averageQuality == null
                    ? 'Avg quality: --'
                    : 'Avg quality: ${averageQuality.toStringAsFixed(1)}/5',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
              Text(
                'Streak: $streak night${streak == 1 ? '' : 's'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
              Text(
                'Logged $loggedNights / 7 nights',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
              if (recentEntries > 0)
                Text(
                  'Goal hits: $goalHitCount / $recentEntries '
                  '(${_formatRate(goalHitCount, recentEntries)})',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              if (consistency != null)
                Text(
                  'Bedtime consistency: ${_formatVarianceMinutes(consistency)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              const SizedBox(height: 6),
              Text(
                averageDuration == null
                    ? 'Goal: ${_formatDuration(goalDuration)}'
                    : _formatGoalDelta(averageDuration, goalDuration),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
              if (averageBedtimeMinutes != null)
                Text(
                  'Avg bedtime: ${_formatMinutesOfDay(averageBedtimeMinutes.round())}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              if (averageWakeMinutes != null)
                Text(
                  'Avg wake: ${_formatMinutesOfDay(averageWakeMinutes.round())}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              if (averageDuration != null && averageQuality != null)
                Text(
                  'Sleep score: ${calculateSleepScore(
                    averageDuration: averageDuration,
                    averageQuality: averageQuality,
                    goalDuration: goalDuration,
                    bedtimeConsistency: consistency,
                  )} / 100',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours <= 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  String _formatGoalDelta(Duration average, Duration goal) {
    final diffMinutes = average.inMinutes - goal.inMinutes;
    if (diffMinutes == 0) return 'On goal this week';
    final direction = diffMinutes > 0 ? 'above' : 'below';
    final diff = Duration(minutes: diffMinutes.abs());
    return 'Avg ${_formatDuration(diff)} $direction goal';
  }

  String _formatVarianceMinutes(double minutes) {
    final rounded = minutes.round();
    if (rounded < 60) return '+/-${rounded}m';
    final hours = rounded ~/ 60;
    final mins = rounded % 60;
    if (mins == 0) return '+/-${hours}h';
    return '+/-${hours}h ${mins}m';
  }

  String _formatMinutesOfDay(int minutes) {
    final normalized = minutes % (24 * 60);
    final hour24 = normalized ~/ 60;
    final minute = normalized % 60;
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatRate(int hits, int total) {
    if (total == 0) return '--';
    final rate = (hits / total * 100).round();
    return '$rate%';
  }
}

class _SleepJournalCard extends ConsumerWidget {
  const _SleepJournalCard({
    required this.activeStart,
    required this.entries,
    required this.sleepGoalMinutes,
  });

  final DateTime? activeStart;
  final List<SleepJournalEntry> entries;
  final int sleepGoalMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appStateProvider.notifier);
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(minutes: 1), (tick) => tick),
      builder: (context, _) => _buildCard(context, notifier),
    );
  }

  Widget _buildCard(BuildContext context, AppStateNotifier notifier) {
    final now = DateTime.now();
    final activeDuration = activeStart == null
        ? null
        : now.difference(activeStart!).isNegative
            ? Duration.zero
            : now.difference(activeStart!);
    final lastEntry = entries.isNotEmpty ? entries.first : null;
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final recent = entries.where((entry) {
      return entry.endedAt.isAfter(weekAgo);
    }).toList();
    final previous = entries.where((entry) {
      return entry.endedAt.isAfter(twoWeeksAgo) &&
          entry.endedAt.isBefore(weekAgo);
    }).toList();
    Duration? averageDuration;
    double? averageQuality;
    Duration? previousAverageDuration;
    double? previousAverageQuality;
    final goalDuration = Duration(minutes: sleepGoalMinutes);
    final bedtimeMinutes = recent
        .map((entry) => _normalizeLateNightMinutes(entry.startedAt))
        .toList();
    final wakeMinutes = recent
        .map((entry) => _normalizeLateNightMinutes(entry.endedAt))
        .toList();
    final averageBedtimeMinutes = _averageMinutes(bedtimeMinutes);
    final averageWakeMinutes = _averageMinutes(wakeMinutes);
    final bedtimeConsistency =
        averageBedtimeMinutes == null || bedtimeMinutes.length < 3
            ? null
            : _meanAbsoluteDeviation(bedtimeMinutes, averageBedtimeMinutes);
    final loggedNights = _countLoggedNights(entries, now, 7);
    final logStreak = _calculateLogStreak(entries, now);
    if (recent.isNotEmpty) {
      final totalMinutes = recent
          .map((entry) => entry.duration.inMinutes)
          .fold<int>(0, (sum, value) => sum + value);
      averageDuration = Duration(
        minutes: (totalMinutes / recent.length).round(),
      );
      final totalQuality = recent
          .map((entry) => entry.quality)
          .fold<int>(0, (sum, value) => sum + value);
      averageQuality = totalQuality / recent.length;
    }
    if (previous.isNotEmpty) {
      final totalMinutes = previous
          .map((entry) => entry.duration.inMinutes)
          .fold<int>(0, (sum, value) => sum + value);
      previousAverageDuration = Duration(
        minutes: (totalMinutes / previous.length).round(),
      );
      final totalQuality = previous
          .map((entry) => entry.quality)
          .fold<int>(0, (sum, value) => sum + value);
      previousAverageQuality = totalQuality / previous.length;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bedtime_outlined),
                const SizedBox(width: 8),
                Text(
                  'Sleep journal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (activeStart != null)
              Text(
                'Sleeping for ${_formatDuration(activeDuration)}',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else if (lastEntry != null)
              Text(
                'Last sleep: ${_formatDuration(lastEntry.duration)}',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Text(
                'Track your sleep with a simple manual log.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (lastEntry != null && activeStart == null) ...[
              const SizedBox(height: 4),
              Text(
                'Ended at ${_formatDateTime(lastEntry.endedAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
              if (lastEntry.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    lastEntry.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: _mutedColor(context)),
                  ),
                ),
            ],
            if (averageDuration != null) ...[
              const SizedBox(height: 8),
              Text(
                '7-day avg: ${_formatDuration(averageDuration)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                averageQuality == null
                    ? 'No quality average yet'
                    : 'Avg quality: ${averageQuality.toStringAsFixed(1)}/5',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
              if (previousAverageDuration != null) ...[
                Builder(
                  builder: (context) {
                    final trend = _formatDurationTrend(
                      averageDuration,
                      previousAverageDuration,
                    );
                    return Text(
                      'Trend: $trend',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: _mutedColor(context)),
                    );
                  },
                ),
              ],
              if (previousAverageQuality != null && averageQuality != null) ...[
                Builder(
                  builder: (context) {
                    final trend = _formatQualityTrend(
                      averageQuality!,
                      previousAverageQuality!,
                    );
                    return Text(
                      'Quality trend: $trend',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: _mutedColor(context)),
                    );
                  },
                ),
              ],
            ],
            if (loggedNights > 0)
              Text(
                'Logged $loggedNights of last 7 nights',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            if (logStreak > 0)
              Text(
                'Logging streak: $logStreak night${logStreak == 1 ? '' : 's'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            const SizedBox(height: 8),
            Text(
              'Goal: ${_formatDuration(goalDuration)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              averageDuration == null
                  ? 'Log sleep to compare with your goal'
                  : _formatGoalDelta(averageDuration, goalDuration),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            if (averageBedtimeMinutes != null)
              Text(
                'Avg bedtime: ${_formatMinutesOfDay(averageBedtimeMinutes.round())}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            if (averageWakeMinutes != null)
              Text(
                'Avg wake: ${_formatMinutesOfDay(averageWakeMinutes.round())}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            if (bedtimeConsistency != null)
              Text(
                'Bedtime consistency: ${_formatVarianceMinutes(bedtimeConsistency)} '
                '(${_consistencyLabel(bedtimeConsistency)})',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            if (averageDuration != null && averageQuality != null)
              Builder(
                builder: (context) {
                  final score = calculateSleepScore(
                    averageDuration: averageDuration!,
                    averageQuality: averageQuality!,
                    goalDuration: goalDuration,
                    bedtimeConsistency: bedtimeConsistency,
                  );
                  return Text(
                    'Sleep score: $score / 100',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: _mutedColor(context)),
                  );
                },
              )
            else
              Text(
                'Sleep score: log more nights to calculate',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            if (bedtimeConsistency == null && bedtimeMinutes.isNotEmpty)
              Text(
                'Consistency needs 3+ logs',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: activeStart == null
                      ? () => notifier.startSleepJournal()
                      : null,
                  child: const Text('Start sleep'),
                ),
                OutlinedButton(
                  onPressed: activeStart != null
                      ? () async {
                          final result =
                              await _showSleepJournalEndSheet(context);
                          if (!context.mounted || result == null) return;
                          await notifier.endSleepJournal(
                            quality: result.quality,
                            notes: result.notes,
                          );
                        }
                      : null,
                  child: const Text('End sleep'),
                ),
                TextButton(
                  onPressed: entries.isEmpty
                      ? null
                      : () => _showSleepJournalHistory(context, entries),
                  child: const Text('View history'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<_SleepJournalResult?> _showSleepJournalEndSheet(
    BuildContext context,
  ) async {
    return showModalBottomSheet<_SleepJournalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        var quality = 3.0;
        var notes = '';
        return StatefulBuilder(
          builder: (sheetContext, setState) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'End sleep',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text('Sleep quality: ${quality.round()} / 5'),
                Slider(
                  min: 1,
                  max: 5,
                  divisions: 4,
                  value: quality,
                  label: '${quality.round()}',
                  onChanged: (value) {
                    setState(() => quality = value);
                  },
                ),
                TextField(
                  maxLines: 3,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => notes = value,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(
                        _SleepJournalResult(
                          quality: quality.round(),
                          notes: notes,
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSleepJournalHistory(
    BuildContext context,
    List<SleepJournalEntry> entries,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bedtime_outlined),
                  const SizedBox(width: 8),
                  Text(
                    'Sleep history',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final subtitleParts = [
                      'Ended at ${_formatDateTime(entry.endedAt)}',
                      'Quality ${entry.quality}/5',
                    ];
                    return ListTile(
                      title: Text('Sleep ${_formatDuration(entry.duration)}'),
                      subtitle: Text(subtitleParts.join(' - ')),
                      trailing: entry.notes.isNotEmpty
                          ? const Icon(Icons.notes_outlined)
                          : null,
                      onTap: entry.notes.isEmpty
                          ? null
                          : () => _showNotes(context, entry),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotes(BuildContext context, SleepJournalEntry entry) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sleep notes'),
        content: Text(entry.notes),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  int _normalizeLateNightMinutes(DateTime time) {
    final minutes = time.hour * 60 + time.minute;
    if (minutes < 12 * 60) {
      return minutes + 24 * 60;
    }
    return minutes;
  }

  double? _averageMinutes(List<int> values) {
    if (values.isEmpty) return null;
    final total = values.fold<int>(0, (sum, value) => sum + value);
    return total / values.length;
  }

  double? _meanAbsoluteDeviation(List<int> values, double mean) {
    if (values.isEmpty) return null;
    final totalDeviation = values.fold<double>(
      0,
      (sum, value) => sum + (value - mean).abs(),
    );
    return totalDeviation / values.length;
  }

  String _formatGoalDelta(Duration average, Duration goal) {
    final diffMinutes = average.inMinutes - goal.inMinutes;
    if (diffMinutes == 0) return 'On goal this week';
    final direction = diffMinutes > 0 ? 'above' : 'below';
    final diff = Duration(minutes: diffMinutes.abs());
    return 'Avg ${_formatDuration(diff)} $direction goal';
  }

  String _formatMinutesOfDay(int minutes) {
    final normalized = minutes % (24 * 60);
    final hour24 = normalized ~/ 60;
    final minute = normalized % 60;
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatVarianceMinutes(double minutes) {
    final rounded = minutes.round();
    if (rounded < 60) return '+/-${rounded}m';
    final hours = rounded ~/ 60;
    final mins = rounded % 60;
    if (mins == 0) return '+/-${hours}h';
    return '+/-${hours}h ${mins}m';
  }

  String _consistencyLabel(double minutes) {
    if (minutes <= 30) return 'steady';
    if (minutes <= 60) return 'okay';
    return 'variable';
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--';
    final totalMinutes = duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours <= 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  String _formatDurationTrend(Duration? current, Duration? previous) {
    if (current == null || previous == null) return '--';
    final diff = current.inMinutes - previous.inMinutes;
    if (diff == 0) return 'flat vs last week';
    final sign = diff > 0 ? '+' : '-';
    final value = diff.abs();
    final hours = value ~/ 60;
    final minutes = value % 60;
    final formatted = hours > 0
        ? (minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m')
        : '${minutes}m';
    return '$sign$formatted vs last week';
  }

  String _formatQualityTrend(double current, double previous) {
    final diff = current - previous;
    if (diff.abs() < 0.05) return 'flat vs last week';
    final sign = diff > 0 ? '+' : '-';
    return '$sign${diff.abs().toStringAsFixed(1)} vs last week';
  }

  int _countLoggedNights(
    List<SleepJournalEntry> entries,
    DateTime now,
    int days,
  ) {
    if (entries.isEmpty || days <= 0) return 0;
    final today = _dateOnly(now.toLocal());
    final cutoff = today.subtract(Duration(days: days - 1));
    final daysLogged = <DateTime>{};
    for (final entry in entries) {
      final date = _dateOnly(entry.endedAt.toLocal());
      if (date.isBefore(cutoff) || date.isAfter(today)) continue;
      daysLogged.add(date);
    }
    return daysLogged.length;
  }

  int _calculateLogStreak(List<SleepJournalEntry> entries, DateTime now) {
    if (entries.isEmpty) return 0;
    final daySet = <DateTime>{};
    for (final entry in entries) {
      daySet.add(_dateOnly(entry.endedAt.toLocal()));
    }
    var day = _dateOnly(now.toLocal());
    if (!daySet.contains(day)) {
      final yesterday = day.subtract(const Duration(days: 1));
      if (daySet.contains(yesterday)) {
        day = yesterday;
      } else {
        return 0;
      }
    }
    var streak = 0;
    while (daySet.contains(day)) {
      streak += 1;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  DateTime _dateOnly(DateTime time) {
    return DateTime(time.year, time.month, time.day);
  }
}

class _SleepJournalResult {
  const _SleepJournalResult({required this.quality, required this.notes});

  final int quality;
  final String notes;
}

class _WeeklySummaryData {
  const _WeeklySummaryData({
    required this.averageDuration,
    required this.averageQuality,
    required this.streak,
    required this.bedtimeConsistency,
    required this.loggedNights,
    required this.goalHitCount,
    required this.recentEntries,
    required this.averageBedtimeMinutes,
    required this.averageWakeMinutes,
  });

  final Duration? averageDuration;
  final double? averageQuality;
  final int streak;
  final double? bedtimeConsistency;
  final int loggedNights;
  final int goalHitCount;
  final int recentEntries;
  final double? averageBedtimeMinutes;
  final double? averageWakeMinutes;
}

_WeeklySummaryData _calculateWeeklySummary(
  List<SleepJournalEntry> entries,
  DateTime now,
  int sleepGoalMinutes,
) {
  final weekAgo = now.subtract(const Duration(days: 7));
  final recent =
      entries.where((entry) => entry.endedAt.isAfter(weekAgo)).toList();
  final recentEntries = recent.length;
  Duration? averageDuration;
  double? averageQuality;
  if (recent.isNotEmpty) {
    final totalMinutes = recent
        .map((entry) => entry.duration.inMinutes)
        .fold<int>(0, (sum, value) => sum + value);
    averageDuration = Duration(minutes: (totalMinutes / recent.length).round());
    final totalQuality = recent
        .map((entry) => entry.quality)
        .fold<int>(0, (sum, value) => sum + value);
    averageQuality = totalQuality / recent.length;
  }
  final bedtimeMinutes = recent
      .map((entry) => _summaryNormalizeLateNightMinutes(entry.startedAt))
      .toList();
  final wakeMinutes = recent
      .map((entry) => _summaryMinutesOfDay(entry.endedAt))
      .toList();
  final averageBedtimeMinutes = _summaryAverageMinutes(bedtimeMinutes);
  final averageWakeMinutes = _summaryAverageMinutes(wakeMinutes);
  final bedtimeConsistency =
      averageBedtimeMinutes == null || bedtimeMinutes.length < 3
          ? null
          : _summaryMeanAbsoluteDeviation(bedtimeMinutes, averageBedtimeMinutes);
  final loggedNights = _summaryCountLoggedNights(entries, now, 7);
  final goalHitCount = recent
      .where((entry) => entry.duration.inMinutes >= sleepGoalMinutes)
      .length;
  final streak = _summaryCalculateLogStreak(entries, now);
  return _WeeklySummaryData(
    averageDuration: averageDuration,
    averageQuality: averageQuality,
    streak: streak,
    bedtimeConsistency: bedtimeConsistency,
    loggedNights: loggedNights,
    goalHitCount: goalHitCount,
    recentEntries: recentEntries,
    averageBedtimeMinutes: averageBedtimeMinutes,
    averageWakeMinutes: averageWakeMinutes,
  );
}

int _summaryNormalizeLateNightMinutes(DateTime time) {
  final minutes = time.hour * 60 + time.minute;
  if (minutes < 12 * 60) {
    return minutes + 24 * 60;
  }
  return minutes;
}

double? _summaryAverageMinutes(List<int> values) {
  if (values.isEmpty) return null;
  final total = values.fold<int>(0, (sum, value) => sum + value);
  return total / values.length;
}

double? _summaryMeanAbsoluteDeviation(List<int> values, double mean) {
  if (values.isEmpty) return null;
  final totalDeviation = values.fold<double>(
    0,
    (sum, value) => sum + (value - mean).abs(),
  );
  return totalDeviation / values.length;
}

int _summaryMinutesOfDay(DateTime time) => time.hour * 60 + time.minute;

int _summaryCountLoggedNights(
  List<SleepJournalEntry> entries,
  DateTime now,
  int days,
) {
  if (entries.isEmpty || days <= 0) return 0;
  final today = _summaryDateOnly(now.toLocal());
  final cutoff = today.subtract(Duration(days: days - 1));
  final daysLogged = <DateTime>{};
  for (final entry in entries) {
    final date = _summaryDateOnly(entry.endedAt.toLocal());
    if (date.isBefore(cutoff) || date.isAfter(today)) continue;
    daysLogged.add(date);
  }
  return daysLogged.length;
}

int _summaryCalculateLogStreak(List<SleepJournalEntry> entries, DateTime now) {
  if (entries.isEmpty) return 0;
  final daySet = <DateTime>{};
  for (final entry in entries) {
    daySet.add(_summaryDateOnly(entry.endedAt.toLocal()));
  }
  var day = _summaryDateOnly(now.toLocal());
  if (!daySet.contains(day)) {
    final yesterday = day.subtract(const Duration(days: 1));
    if (daySet.contains(yesterday)) {
      day = yesterday;
    } else {
      return 0;
    }
  }
  var streak = 0;
  while (daySet.contains(day)) {
    streak += 1;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

DateTime _summaryDateOnly(DateTime time) {
  return DateTime(time.year, time.month, time.day);
}

Future<void> _shareWeeklySummary(
  BuildContext context,
  List<SleepJournalEntry> entries,
  int sleepGoalMinutes,
) async {
  if (entries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No sleep entries to share yet')),
    );
    return;
  }
  final summary =
      _calculateWeeklySummary(entries, DateTime.now(), sleepGoalMinutes);
  final goalDuration = Duration(minutes: sleepGoalMinutes);
  final summaryText = StringBuffer()
    ..writeln('NightBuddy weekly summary')
    ..writeln(
      'Average sleep: ${summary.averageDuration == null ? '--' : _formatSummaryDuration(summary.averageDuration!)}',
    )
    ..writeln(
      'Average quality: ${summary.averageQuality == null ? '--' : summary.averageQuality!.toStringAsFixed(1)}/5',
    )
    ..writeln('Streak: ${summary.streak} night(s)')
    ..writeln(
      'Bedtime consistency: ${summary.bedtimeConsistency == null ? '--' : _formatSummaryVariance(summary.bedtimeConsistency!)}',
    );
  if (summary.loggedNights > 0) {
    summaryText.writeln('Logged nights: ${summary.loggedNights} / 7');
  }
  if (summary.recentEntries > 0) {
    summaryText.writeln(
      'Goal hits: ${summary.goalHitCount} / ${summary.recentEntries}',
    );
  }
  if (summary.averageBedtimeMinutes != null) {
    summaryText.writeln(
      'Avg bedtime: ${_formatSummaryMinutes(summary.averageBedtimeMinutes!.round())}',
    );
  }
  if (summary.averageWakeMinutes != null) {
    summaryText.writeln(
      'Avg wake: ${_formatSummaryMinutes(summary.averageWakeMinutes!.round())}',
    );
  }
  if (summary.averageDuration != null && summary.averageQuality != null) {
    final score = calculateSleepScore(
      averageDuration: summary.averageDuration!,
      averageQuality: summary.averageQuality!,
      goalDuration: goalDuration,
      bedtimeConsistency: summary.bedtimeConsistency,
    );
    summaryText.writeln('Sleep score: $score / 100');
  }

  await Share.share(
    summaryText.toString(),
    subject: 'NightBuddy weekly summary',
  );
}

String _formatSummaryDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours <= 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _formatSummaryVariance(double minutes) {
  final rounded = minutes.round();
  if (rounded < 60) return '+/-${rounded}m';
  final hours = rounded ~/ 60;
  final mins = rounded % 60;
  if (mins == 0) return '+/-${hours}h';
  return '+/-${hours}h ${mins}m';
}

String _formatSummaryMinutes(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  return '$hour:${minute.toString().padLeft(2, '0')} $period';
}

class _OverlayDebugCard extends ConsumerWidget {
  const _OverlayDebugCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(overlayDebugInfoProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: info.when(
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debug: Overlay service',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text('Permission: ${data.hasPermission ? 'granted' : 'missing'}'),
              Text(
                'Native enabled: ${data.isEnabled == null ? 'unknown' : (data.isEnabled! ? 'true' : 'false')}',
              ),
            ],
          ),
          loading: () => const Text('Debug: Checking overlay status...'),
          error: (_, stackTrace) =>
              const Text('Debug: Overlay status unavailable'),
        ),
      ),
    );
  }
}

class _OverlayDebugInfo {
  const _OverlayDebugInfo({
    required this.hasPermission,
    required this.isEnabled,
  });

  final bool hasPermission;
  final bool? isEnabled;
}

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

class _PresetCarousel extends StatelessWidget {
  const _PresetCarousel({required this.state, required this.onSelectPreset});

  final AppState state;
  final ValueChanged<FilterPreset> onSelectPreset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Presets', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: state.presets.map((preset) {
              final selected = preset.id == state.activePresetId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PresetChip(
                  preset: preset,
                  selected: selected,
                  isPremiumLocked: !state.isPremium,
                  onSelected: () => onSelectPreset(preset),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SliderValues {
  _SliderValues({this.temperature, this.opacity, this.brightness});

  final double? temperature;
  final double? opacity;
  final double? brightness;
}

class _SlidersSection extends StatefulWidget {
  const _SlidersSection({required this.state, required this.onChanged});

  final AppState state;
  final ValueChanged<_SliderValues> onChanged;

  @override
  State<_SlidersSection> createState() => _SlidersSectionState();
}

class _SlidersSectionState extends State<_SlidersSection> {
  late double _temperature;
  late double _opacity;
  late double _brightness;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final preset = widget.state.activePreset;
    _temperature = preset.temperature;
    _opacity = preset.opacity;
    _brightness = preset.brightness;
  }

  @override
  void didUpdateWidget(covariant _SlidersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.activePresetId != widget.state.activePresetId) {
      final preset = widget.state.activePreset;
      _temperature = preset.temperature;
      _opacity = preset.opacity;
      _brightness = preset.brightness;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preset = widget.state.activePreset;
    final isLocked = preset.isPremium && !widget.state.isPremium;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tune filter', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1.8,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                  ),
                  FilterPreviewOverlay(
                    preset: preset,
                    active: widget.state.isFilterActive(DateTime.now()),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        preset.name,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                _buildSlider(
                  context: context,
                  label: 'Temperature',
                  value: _temperature,
                  onChanged: isLocked
                      ? null
                      : (value) {
                          setState(() => _temperature = value);
                          _queueUpdate();
                        },
                ),
                _buildSlider(
                  context: context,
                  label: 'Opacity',
                  value: _opacity,
                  onChanged: isLocked
                      ? null
                      : (value) {
                          setState(() => _opacity = value);
                          _queueUpdate();
                        },
                ),
                _buildSlider(
                  context: context,
                  label: 'Brightness',
                  value: _brightness,
                  onChanged: isLocked
                      ? null
                      : (value) {
                          setState(() => _brightness = value);
                          _queueUpdate();
                        },
                ),
                if (isLocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Premium controls',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.amber),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required BuildContext context,
    required String label,
    required double value,
    required ValueChanged<double>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value.toStringAsFixed(0))],
        ),
        Slider(
          min: 0,
          max: 100,
          divisions: 20,
          value: value.clamp(0, 100),
          label: value.toStringAsFixed(0),
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _queueUpdate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 160), () {
      widget.onChanged(
        _SliderValues(
          temperature: _temperature,
          opacity: _opacity,
          brightness: _brightness,
        ),
      );
    });
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.state, required this.onOpen});

  final AppState state;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    final schedule = state.schedule;
    final now = DateTime.now();
    final nextChange = state.nextScheduleChange(now);
    final scheduleLabel = _subtitle(schedule);
    final nextLabel = nextChange == null
        ? null
        : (state.isFilterActive(now)
            ? 'On until ${_formatDateTime(nextChange)}'
            : 'Starts at ${_formatDateTime(nextChange)}');
    final subtitle =
        nextLabel == null ? scheduleLabel : '$scheduleLabel\n$nextLabel';

    return Card(
      child: ListTile(
        title: const Text('Schedule'),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final navigator = Navigator.of(context);
          await onOpen();
          navigator.push(
            MaterialPageRoute(builder: (_) => const ScheduleScreen()),
          );
        },
      ),
    );
  }

  String _subtitle(ScheduleConfig schedule) {
    switch (schedule.mode) {
      case FilterMode.off:
        return 'Off';
      case FilterMode.alwaysOn:
        return 'Always on';
      case FilterMode.scheduled:
        final start = _format(schedule.startTime);
        final end = _format(schedule.endTime);
        return '$start - $end';
    }
  }

  String _format(TimeOfDay? time) {
    if (time == null) return '--';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDateTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _ScheduleTimelineCard extends StatelessWidget {
  const _ScheduleTimelineCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final schedule = state.schedule;
    final now = DateTime.now();
    final start = _effectiveScheduleStart(schedule, now);
    final end = _effectiveScheduleEnd(schedule, now);
    if (schedule.mode != FilterMode.scheduled || start == null || end == null) {
      return const SizedBox.shrink();
    }

    final nextStart = _nextStartTime(now, start);
    final nextEnd = _nextEnd(now, start, end);
    final windDownMinutes = schedule.windDownMinutes;
    final fadeOutMinutes = schedule.fadeOutMinutes;
    final activeMinutes = _activeWindowMinutes(start, end);
    final totalMinutes =
        windDownMinutes + activeMinutes + fadeOutMinutes;
    final windDownFlex = windDownMinutes > 0 ? windDownMinutes : null;
    final activeFlex = activeMinutes > 0 ? activeMinutes : 1;
    final fadeOutFlex = fadeOutMinutes > 0 ? fadeOutMinutes : null;
    final windDownStart =
        windDownMinutes > 0 ? nextStart.subtract(Duration(minutes: windDownMinutes)) : null;
    final fadeOutEnd =
        fadeOutMinutes > 0 ? nextEnd.add(Duration(minutes: fadeOutMinutes)) : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline_outlined),
                const SizedBox(width: 8),
                Text(
                  'Tonight\'s timeline',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Start ${_formatDateTime(nextStart)} - End ${_formatDateTime(nextEnd)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (windDownFlex != null)
                  Expanded(
                    flex: windDownFlex,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                if (windDownFlex != null) const SizedBox(width: 4),
                Expanded(
                  flex: activeFlex,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                if (fadeOutFlex != null) const SizedBox(width: 4),
                if (fadeOutFlex != null)
                  Expanded(
                    flex: fadeOutFlex,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (windDownStart != null)
              Text(
                'Wind-down begins at ${_formatDateTime(windDownStart)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            Text(
              'Filter active from ${_formatDateTime(nextStart)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            if (fadeOutEnd != null)
              Text(
                'Fade-out ends at ${_formatDateTime(fadeOutEnd)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            const SizedBox(height: 6),
            Text(
              'Total window: ${_formatDuration(Duration(minutes: totalMinutes))}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _nextEnd(DateTime now, TimeOfDay start, TimeOfDay end) {
    final startDate = _nextStartTime(now, start);
    var endDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      end.hour,
      end.minute,
    );
    if (!endDate.isAfter(startDate)) {
      endDate = endDate.add(const Duration(days: 1));
    }
    return endDate;
  }

  int _activeWindowMinutes(TimeOfDay start, TimeOfDay end) {
    final startMinutes = _minutesOfDay(start);
    final endMinutes = _minutesOfDay(end);
    if (startMinutes == endMinutes) return 24 * 60;
    if (endMinutes > startMinutes) return endMinutes - startMinutes;
    return (24 * 60) - startMinutes + endMinutes;
  }

  String _formatDateTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours <= 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}

class _PlannerStep {
  const _PlannerStep({
    required this.label,
    required this.when,
    required this.icon,
  });

  final String label;
  final DateTime when;
  final IconData icon;
}

class _WindDownPlannerCard extends StatelessWidget {
  const _WindDownPlannerCard({
    required this.state,
    required this.onOpenSchedule,
  });

  final AppState state;
  final Future<void> Function() onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final schedule = state.schedule;
    final now = DateTime.now();
    final startTime = _plannerStartTime(state, now);
    final endTime = _effectiveScheduleEnd(schedule, now);
    final hasSchedule =
        schedule.mode == FilterMode.scheduled &&
            startTime != null &&
            endTime != null;

    if (!hasSchedule) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.timeline_outlined),
          title: const Text('Wind-down planner'),
          subtitle: const Text('Set a schedule to build your bedtime plan.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpenSchedule,
        ),
      );
    }

    final nextStart = _nextStartTime(now, startTime);
    final windDownMinutes =
        schedule.windDownMinutes > 0 ? schedule.windDownMinutes : 30;
    final cutoffHours =
        state.caffeineCutoffHours > 0 ? state.caffeineCutoffHours : 6;
    final steps = [
      _PlannerStep(
        label: 'Caffeine cutoff',
        when: nextStart.subtract(Duration(hours: cutoffHours)),
        icon: Icons.local_cafe_outlined,
      ),
      _PlannerStep(
        label: 'Dim lights + slow down',
        when: nextStart.subtract(const Duration(hours: 2)),
        icon: Icons.lightbulb_outline,
      ),
      _PlannerStep(
        label: 'Start wind-down routine',
        when: nextStart.subtract(Duration(minutes: windDownMinutes)),
        icon: Icons.nightlight_outlined,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline_outlined),
                const SizedBox(width: 8),
                Text(
                  'Wind-down planner',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Target bedtime: ${_formatTimeOfDay(startTime)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            if (state.sunsetSyncEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Sunset sync: ${_formatTimeOfDay(_sunsetLabel(state, now))}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              ),
            const SizedBox(height: 12),
            ...steps.map(
              (step) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(step.icon, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(step.label)),
                    Text(
                      _formatTime(step.when),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: _mutedColor(context)),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpenSchedule,
                child: const Text('Adjust schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '--';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class _ScreenOffGoalCard extends ConsumerWidget {
  const _ScreenOffGoalCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appStateProvider.notifier);
    final end = state.screenOffUntil;
    final primaryMinutes =
        state.screenOffGoalMinutes > 0 ? state.screenOffGoalMinutes : 60;
    var secondaryMinutes = primaryMinutes + 30;
    if (secondaryMinutes == primaryMinutes) {
      secondaryMinutes = primaryMinutes + 60;
    }
    if (secondaryMinutes > 180) {
      secondaryMinutes = 180;
    }

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 30), (tick) => tick),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final remaining = end?.difference(now);
        final endLabel = end?.clockLabel();
        final scheduleStart = _plannerStartTime(state, now);
        final scheduleEnd = _effectiveScheduleEnd(state.schedule, now);
        final windowStart = scheduleStart == null || scheduleEnd == null
            ? null
            : _currentOrNextStart(now, scheduleStart, scheduleEnd);
        final goalStart = windowStart == null
            ? null
            : windowStart.subtract(Duration(minutes: primaryMinutes));
        final shouldStart = goalStart != null &&
            now.isAfter(goalStart) &&
            end == null &&
            state.schedule.mode == FilterMode.scheduled;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_locked_outlined),
                    const SizedBox(width: 8),
                    Text(
                      'Screen-off goal',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  end == null
                      ? 'Set a short no-phone window before bed.'
                      : 'Remaining: ${_formatDuration(remaining)}'
                          '${endLabel == null ? '' : ' (ends at $endLabel)'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
                if (shouldStart)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Your screen-off window should start now.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.amber),
                    ),
                  ),
                const SizedBox(height: 12),
                if (end == null)
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => notifier.startScreenOffGoal(
                          Duration(minutes: primaryMinutes),
                        ),
                        child: Text('$primaryMinutes min'),
                      ),
                      OutlinedButton(
                        onPressed: () => notifier.startScreenOffGoal(
                          Duration(minutes: secondaryMinutes),
                        ),
                        child: Text('$secondaryMinutes min'),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: notifier.endScreenOffGoal,
                      child: const Text('End now'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--';
    if (duration.isNegative) return '0m';
    final totalMinutes = duration.inMinutes;
    if (totalMinutes <= 0) return '0m';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _SoundscapeOption {
  const _SoundscapeOption({
    required this.id,
    required this.label,
    required this.asset,
  });

  final String id;
  final String label;
  final String asset;
}

class _SoundscapesCard extends StatefulWidget {
  const _SoundscapesCard();

  @override
  State<_SoundscapesCard> createState() => _SoundscapesCardState();
}

class _SoundscapesCardState extends State<_SoundscapesCard> {
  static const _options = [
    _SoundscapeOption(
      id: 'rain',
      label: 'Rain',
      asset: 'assets/sounds/soft_noise.wav',
    ),
    _SoundscapeOption(
      id: 'fan',
      label: 'Fan',
      asset: 'assets/sounds/soft_noise.wav',
    ),
    _SoundscapeOption(
      id: 'ocean',
      label: 'Ocean',
      asset: 'assets/sounds/soft_noise.wav',
    ),
  ];

  final AudioPlayer _player = AudioPlayer();
  String? _activeId;
  DateTime? _endTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _player.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(_SoundscapeOption option) async {
    _timer?.cancel();
    try {
      await _player.stop();
      await _player.play(AssetSource(option.asset));
      setState(() => _activeId = option.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soundscape unavailable')),
      );
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _player.stop();
    setState(() {
      _activeId = null;
      _endTime = null;
    });
  }

  void _startTimer(Duration duration) {
    _timer?.cancel();
    setState(() => _endTime = DateTime.now().add(duration));
    _timer = Timer(duration, () {
      if (!mounted) return;
      _stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _options.firstWhere(
      (option) => option.id == _activeId,
      orElse: () => _options.first,
    );
    final isPlaying = _activeId != null;
    final remaining = _endTime?.difference(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.headphones_outlined),
                const SizedBox(width: 8),
                Text(
                  'Soundscapes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isPlaying
                  ? 'Playing ${active.label}'
                  : 'Pick a calming loop for wind-down.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            if (remaining != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Timer: ${_formatDuration(remaining)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _options.map((option) {
                final selected = option.id == _activeId;
                return ChoiceChip(
                  label: Text(option.label),
                  selected: selected,
                  onSelected: (_) => _play(option),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: isPlaying ? () => _startTimer(const Duration(minutes: 15)) : null,
                  child: const Text('15m'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: isPlaying ? () => _startTimer(const Duration(minutes: 30)) : null,
                  child: const Text('30m'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: isPlaying ? () => _startTimer(const Duration(minutes: 60)) : null,
                  child: const Text('60m'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: isPlaying ? _stop : null,
                  child: const Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '0m';
    final minutes = duration.inMinutes;
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}

class _CaffeineCutoffCard extends StatelessWidget {
  const _CaffeineCutoffCard({
    required this.state,
    required this.onOpenSchedule,
  });

  final AppState state;
  final Future<void> Function() onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final schedule = state.schedule;
    final now = DateTime.now();
    final startTime = _plannerStartTime(state, now);
    final endTime = _effectiveScheduleEnd(schedule, now);
    final hasSchedule =
        schedule.mode == FilterMode.scheduled &&
            startTime != null &&
            endTime != null;

    if (!hasSchedule) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.local_cafe_outlined),
          title: const Text('Caffeine cutoff'),
          subtitle: const Text('Set a schedule to get a cutoff reminder.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpenSchedule,
        ),
      );
    }

    final nextStart = _nextStartTime(now, startTime);
    final cutoffHours =
        state.caffeineCutoffHours > 0 ? state.caffeineCutoffHours : 6;
    final cutoff = nextStart.subtract(Duration(hours: cutoffHours));
    final remaining = cutoff.difference(now);
    final status = remaining.isNegative
        ? 'Cutoff passed'
        : 'Cutoff in ${_formatDuration(remaining)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_cafe_outlined),
                const SizedBox(width: 8),
                Text(
                  'Caffeine cutoff',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Avoid caffeine after ${_formatTime(cutoff)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 6),
            Text(
              status,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: remaining.isNegative ? Colors.amber : _mutedColor(context),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '0m';
    final totalMinutes = duration.inMinutes;
    if (totalMinutes <= 0) return '0m';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}

class _BlueLightGoalCard extends StatelessWidget {
  const _BlueLightGoalCard({
    required this.state,
    required this.onOpenSchedule,
  });

  final AppState state;
  final Future<void> Function() onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final schedule = state.schedule;
    final now = DateTime.now();
    final goalMinutes =
        state.blueLightGoalMinutes > 0 ? state.blueLightGoalMinutes : 120;
    final startTime = _plannerStartTime(state, now);
    final endTime = _effectiveScheduleEnd(schedule, now);
    final hasSchedule =
        schedule.mode == FilterMode.scheduled &&
            startTime != null &&
            endTime != null;

    if (!hasSchedule) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.track_changes_outlined),
          title: const Text('Blue-light goal'),
          subtitle: const Text('Set a schedule to track your wind-down goal.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpenSchedule,
        ),
      );
    }

    final windowStart = _currentOrNextStart(now, startTime, endTime);
    final goalStart = windowStart.subtract(Duration(minutes: goalMinutes));
    final shouldCount =
        state.isFilterActive(now) && now.isAfter(goalStart);
    final progressMinutes = shouldCount
        ? now.difference(goalStart).inMinutes.clamp(0, goalMinutes)
        : 0;
    final behind = now.isAfter(goalStart) && !state.isFilterActive(now);
    final missed = now.isAfter(windowStart) && progressMinutes < goalMinutes;
    final progress = progressMinutes / goalMinutes;
    final status = progress >= 1
        ? 'Goal reached'
        : (now.isBefore(goalStart)
            ? 'Starts at ${_formatTime(goalStart)}'
            : 'In progress');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.track_changes_outlined),
                const SizedBox(width: 8),
                Text(
                  'Blue-light goal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$progressMinutes / $goalMinutes minutes before bed',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            const SizedBox(height: 6),
            Text(
              status,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            if (behind)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Filter is off - goal paused.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.amber),
                ),
              ),
            if (missed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Goal missed for tonight. Resume tomorrow.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _MorningCheckInCard extends ConsumerWidget {
  const _MorningCheckInCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final lastEntry =
        state.sleepJournalEntries.isNotEmpty ? state.sleepJournalEntries.first : null;
    final loggedToday =
        lastEntry != null && _isSameDay(lastEntry.endedAt.toLocal(), now);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_sunny_outlined),
                const SizedBox(width: 8),
                Text(
                  'Morning check-in',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              loggedToday
                  ? 'You already checked in today.'
                  : 'Log how you slept this morning.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            if (lastEntry != null) ...[
              const SizedBox(height: 6),
              Text(
                'Last quality: ${lastEntry.quality}/5',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: loggedToday
                    ? null
                    : () async {
                        final result = await _showQuickLogSheet(
                          context,
                          state,
                        );
                        if (!context.mounted || result == null) return;
                        await ref
                            .read(appStateProvider.notifier)
                            .addSleepJournalEntry(result);
                      },
                child: const Text('Quick log'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<SleepJournalEntry?> _showQuickLogSheet(
    BuildContext context,
    AppState state,
  ) async {
    final schedule = state.schedule;
    final now = DateTime.now();
    final defaultStart =
        _effectiveStartTime(schedule, now) ?? const TimeOfDay(hour: 23, minute: 0);
    final defaultEnd =
        _effectiveEndTime(schedule, now) ?? const TimeOfDay(hour: 7, minute: 0);

    return showModalBottomSheet<SleepJournalEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        var startTime = defaultStart;
        var endTime = defaultEnd;
        var quality = 3.0;
        var notes = '';
        return StatefulBuilder(
          builder: (sheetContext, setState) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Morning check-in',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: sheetContext,
                            initialTime: startTime,
                          );
                          if (picked == null) return;
                          setState(() => startTime = picked);
                        },
                        child: Text('Bedtime: ${_formatTimeOfDay(startTime)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: sheetContext,
                            initialTime: endTime,
                          );
                          if (picked == null) return;
                          setState(() => endTime = picked);
                        },
                        child: Text('Wake: ${_formatTimeOfDay(endTime)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Sleep quality: ${quality.round()} / 5'),
                Slider(
                  min: 1,
                  max: 5,
                  divisions: 4,
                  value: quality,
                  label: '${quality.round()}',
                  onChanged: (value) => setState(() => quality = value),
                ),
                TextField(
                  maxLines: 3,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => notes = value,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final entry = _buildEntry(
                          now: DateTime.now(),
                          start: startTime,
                          end: endTime,
                          quality: quality.round(),
                          notes: notes,
                        );
                        Navigator.of(sheetContext).pop(entry);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  SleepJournalEntry _buildEntry({
    required DateTime now,
    required TimeOfDay start,
    required TimeOfDay end,
    required int quality,
    required String notes,
  }) {
    var endedAt = DateTime(now.year, now.month, now.day, end.hour, end.minute);
    if (endedAt.isAfter(now)) {
      endedAt = endedAt.subtract(const Duration(days: 1));
    }
    var startedAt =
        DateTime(endedAt.year, endedAt.month, endedAt.day, start.hour, start.minute);
    if (startedAt.isAfter(endedAt)) {
      startedAt = startedAt.subtract(const Duration(days: 1));
    }
    return SleepJournalEntry(
      startedAt: startedAt,
      endedAt: endedAt,
      quality: quality.clamp(1, 5),
      notes: notes.trim(),
    );
  }

  TimeOfDay? _effectiveStartTime(ScheduleConfig schedule, DateTime now) {
    if (!schedule.weekendDifferent) return schedule.startTime;
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    if (!isWeekend) return schedule.startTime;
    return schedule.weekendStartTime ?? schedule.startTime;
  }

  TimeOfDay? _effectiveEndTime(ScheduleConfig schedule, DateTime now) {
    if (!schedule.weekendDifferent) return schedule.endTime;
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    if (!isWeekend) return schedule.endTime;
    return schedule.weekendEndTime ?? schedule.endTime;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _FlashlightCard extends ConsumerWidget {
  const _FlashlightCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(flashlightAvailableProvider);
    final notifier = ref.read(appStateProvider.notifier);

    return availability.when(
      data: (hasFlash) {
        final enabled = state.flashlightEnabled && hasFlash;
        return Card(
          child: ListTile(
            leading: Icon(
              enabled ? Icons.flash_on : Icons.flash_off,
              color: enabled ? Colors.amber : null,
            ),
            title: const Text('Flashlight'),
            subtitle: Text(
              hasFlash
                  ? (enabled ? 'On' : 'Off')
                  : 'Not available on this device',
            ),
            trailing: Switch(
              value: enabled,
              onChanged: hasFlash
                  ? (value) async {
                      final ok = await notifier.toggleFlashlight(value);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Flashlight unavailable or permission required',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
            ),
            onTap: hasFlash
                ? () async {
                    final ok = await notifier.toggleFlashlight(!enabled);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Flashlight unavailable or permission required',
                          ),
                        ),
                      );
                    }
                  }
                : null,
          ),
        );
      },
      loading: () => const Card(
        child: ListTile(
          leading: CircularProgressIndicator(strokeWidth: 2),
          title: Text('Flashlight'),
          subtitle: Text('Checking availability...'),
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

class _PremiumCta extends StatelessWidget {
  const _PremiumCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.workspace_premium_outlined),
        title: const Text('Unlock premium presets and controls'),
        subtitle: const Text(
          'Remove ads, extra warmth, and advanced scheduling',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _AdArea extends ConsumerWidget {
  const _AdArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ads = ref.read(adsServiceProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sponsored', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Center(child: AdsBanner(adUnitId: ads.bannerAdUnitId)),
          ],
        ),
      ),
    );
  }
}

TimeOfDay? _plannerStartTime(AppState state, DateTime now) {
  final schedule = state.schedule;
  final scheduled = _effectiveScheduleStart(schedule, now);
  if (!state.sunsetSyncEnabled) return scheduled;
  final sunset = state.sunsetTime ?? _approxSunsetTime(now);
  if (scheduled == null) return sunset;
  return _minutesOfDay(sunset) < _minutesOfDay(scheduled) ? sunset : scheduled;
}

TimeOfDay? _effectiveScheduleStart(ScheduleConfig schedule, DateTime now) {
  if (!schedule.weekendDifferent) return schedule.startTime;
  final isWeekend =
      now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  if (!isWeekend) return schedule.startTime;
  return schedule.weekendStartTime ?? schedule.startTime;
}

TimeOfDay? _effectiveScheduleEnd(ScheduleConfig schedule, DateTime now) {
  if (!schedule.weekendDifferent) return schedule.endTime;
  final isWeekend =
      now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  if (!isWeekend) return schedule.endTime;
  return schedule.weekendEndTime ?? schedule.endTime;
}

TimeOfDay _approxSunsetTime(DateTime now) {
  switch (now.month) {
    case 12:
    case 1:
      return const TimeOfDay(hour: 17, minute: 0);
    case 2:
      return const TimeOfDay(hour: 17, minute: 30);
    case 3:
      return const TimeOfDay(hour: 18, minute: 15);
    case 4:
      return const TimeOfDay(hour: 19, minute: 0);
    case 5:
      return const TimeOfDay(hour: 20, minute: 0);
    case 6:
      return const TimeOfDay(hour: 20, minute: 30);
    case 7:
      return const TimeOfDay(hour: 20, minute: 15);
    case 8:
      return const TimeOfDay(hour: 19, minute: 45);
    case 9:
      return const TimeOfDay(hour: 19, minute: 0);
    case 10:
      return const TimeOfDay(hour: 18, minute: 15);
    case 11:
      return const TimeOfDay(hour: 17, minute: 30);
    default:
      return const TimeOfDay(hour: 18, minute: 30);
  }
}

int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

DateTime _currentOrNextStart(
  DateTime now,
  TimeOfDay start,
  TimeOfDay end,
) {
  final startToday =
      DateTime(now.year, now.month, now.day, start.hour, start.minute);
  var endForStart =
      DateTime(now.year, now.month, now.day, end.hour, end.minute);
  if (!endForStart.isAfter(startToday)) {
    endForStart = endForStart.add(const Duration(days: 1));
  }
  if (now.isBefore(startToday) && endForStart.day != startToday.day) {
    return startToday.subtract(const Duration(days: 1));
  }
  if (now.isAfter(startToday) && now.isBefore(endForStart)) {
    return startToday;
  }
  if (now.isBefore(startToday)) return startToday;
  return startToday.add(const Duration(days: 1));
}

DateTime _nextStartTime(DateTime now, TimeOfDay start) {
  final candidate =
      DateTime(now.year, now.month, now.day, start.hour, start.minute);
  if (candidate.isAfter(now)) return candidate;
  return candidate.add(const Duration(days: 1));
}

TimeOfDay _sunsetLabel(AppState state, DateTime now) {
  if (state.sunsetTime != null &&
      state.sunsetUpdatedAt != null &&
      state.sunsetUpdatedAt!.year == now.year &&
      state.sunsetUpdatedAt!.month == now.month &&
      state.sunsetUpdatedAt!.day == now.day) {
    return state.sunsetTime!;
  }
  return _approxSunsetTime(now);
}

extension _DateTimeClockLabel on DateTime {
  String clockLabel() {
    final local = toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
