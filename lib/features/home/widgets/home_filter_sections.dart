import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/filter_models.dart';
import '../../../state/app_state.dart';
import '../../../widgets/filter_preview_overlay.dart';
import '../../../widgets/preset_chip.dart';

class HomeOverlayPermissionBanner extends StatelessWidget {
  const HomeOverlayPermissionBanner({super.key, required this.onEnable});

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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
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

class HomeOverlayWatchdogBanner extends StatelessWidget {
  const HomeOverlayWatchdogBanner({
    super.key,
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
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
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

class HomeStatusCard extends StatelessWidget {
  const HomeStatusCard({
    super.key,
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: _mutedColor(context)),
                        ),
                      Text(
                        _scheduleLabel(state.schedule),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _mutedColor(context),
                        ),
                      ),
                      if (state.schedule.mode == FilterMode.scheduled &&
                          (state.schedule.windDownMinutes > 0 ||
                              state.schedule.fadeOutMinutes > 0))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _rampLabel(),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color:
                                      (state.isWindDownActive(now) ||
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: _mutedColor(context)),
                        ),
                      ),
                      if (snoozedUntil != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Snoozed until ${_formatDateTime(snoozedUntil!)}',
                            style: Theme.of(context).textTheme.bodySmall
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
                  onPressed: nextChange == null
                      ? null
                      : () async {
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

class HomePresetCarousel extends StatelessWidget {
  const HomePresetCarousel({
    super.key,
    required this.state,
    required this.onSelectPreset,
  });

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

class SliderValues {
  SliderValues({this.temperature, this.opacity, this.brightness});

  final double? temperature;
  final double? opacity;
  final double? brightness;
}

class HomeSlidersSection extends StatefulWidget {
  const HomeSlidersSection({
    super.key,
    required this.state,
    required this.onChanged,
    required this.onSelectPreset,
    required this.onToggleFavoritePreset,
  });

  final AppState state;
  final ValueChanged<SliderValues> onChanged;
  final Future<void> Function(String presetId) onSelectPreset;
  final Future<void> Function(String? presetId) onToggleFavoritePreset;

  @override
  State<HomeSlidersSection> createState() => _HomeSlidersSectionState();
}

class _HomeSlidersSectionState extends State<HomeSlidersSection> {
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
  void didUpdateWidget(covariant HomeSlidersSection oldWidget) {
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
    final isFavorite = widget.state.favoritePresetId == preset.id;
    final favoritePresetId = widget.state.favoritePresetId;
    final favoritePreset = favoritePresetId == null
        ? null
        : widget.state.presets.cast<FilterPreset?>().firstWhere(
            (item) => item?.id == favoritePresetId,
            orElse: () => null,
          );
    final previewPreset = FilterPreset(
      id: preset.id,
      name: preset.name,
      temperature: _temperature,
      opacity: _opacity,
      brightness: _brightness,
      isPremium: preset.isPremium,
      isCustom: preset.isCustom,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tune filter', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: Icon(
                    preset.isCustom
                        ? Icons.tune_outlined
                        : Icons.auto_awesome_outlined,
                    size: 16,
                  ),
                  label: Text(preset.name),
                ),
                Text(
                  _presetFeelLabel(
                    temperature: _temperature,
                    opacity: _opacity,
                    brightness: _brightness,
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
                ),
                ActionChip(
                  avatar: Icon(
                    isFavorite ? Icons.star : Icons.star_outline,
                    size: 16,
                  ),
                  label: Text(isFavorite ? 'Favorite preset' : 'Make favorite'),
                  onPressed: () {
                    widget.onToggleFavoritePreset(
                      isFavorite ? null : preset.id,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Preview first, then fine-tune the warmth, tint strength, and dimness.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
            if (favoritePreset != null && favoritePreset.id != preset.id)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => widget.onSelectPreset(favoritePreset.id),
                    icon: const Icon(Icons.star, size: 18),
                    label: Text('Use favorite preset: ${favoritePreset.name}'),
                  ),
                ),
              ),
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
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilterPhonePreview(
                        preset: previewPreset,
                        active: widget.state.isFilterActive(DateTime.now()),
                        label: preset.name,
                        helper: _presetFeelLabel(
                          temperature: _temperature,
                          opacity: _opacity,
                          brightness: _brightness,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FilterPreviewScreen(
                        preset: previewPreset,
                        active: widget.state.isFilterActive(DateTime.now()),
                      ),
                    ),
                  );
                },
                child: const Text('Open full preview'),
              ),
            ),
            const SizedBox(height: 4),
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
        SliderValues(
          temperature: _temperature,
          opacity: _opacity,
          brightness: _brightness,
        ),
      );
    });
  }

  String _presetFeelLabel({
    required double temperature,
    required double opacity,
    required double brightness,
  }) {
    final warmth = temperature >= 75
        ? 'Very warm'
        : temperature >= 50
        ? 'Balanced warmth'
        : 'Light warmth';
    final tint = opacity >= 70
        ? 'strong tint'
        : opacity >= 40
        ? 'steady tint'
        : 'soft tint';
    final dim = brightness <= 40
        ? 'darker screen'
        : brightness <= 70
        ? 'gentle dimming'
        : 'brighter screen';
    return '$warmth, $tint, $dim';
  }
}

class FilterPreviewScreen extends StatelessWidget {
  const FilterPreviewScreen({
    super.key,
    required this.preset,
    required this.active,
  });

  final FilterPreset preset;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Filter preview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'This mock phone shows how your current warmth, opacity, and brightness settings can feel on-screen.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _mutedColor(context)),
          ),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: FilterPhonePreview(
                preset: preset,
                active: active,
                label: preset.name,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: Text(preset.name),
              subtitle: Text(
                'Temperature ${preset.temperature.round()} | '
                'Opacity ${preset.opacity.round()} | '
                'Brightness ${preset.brightness.round()}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
