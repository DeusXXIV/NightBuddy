import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/filter_models.dart';
import '../../services/ads_service.dart';
import '../../services/overlay_service.dart';
import '../../state/app_notifier.dart';
import '../../state/app_state.dart';
import '../../widgets/ads_banner.dart';
import '../../widgets/filter_preview_overlay.dart';
import '../../widgets/preset_chip.dart';
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

class _HomeView extends ConsumerWidget {
  const _HomeView({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appStateProvider.notifier);
    final now = DateTime.now();
    final isActive = state.isFilterActive(now);

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
            _StatusCard(
              state: state,
              isActive: isActive,
              onToggle: (value) async {
                if (value) {
                  final overlayService = ref.read(overlayServiceProvider);
                  final hasPermission = await overlayService.hasPermission();
                  if (!hasPermission && context.mounted) {
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
                    if (shouldOpen != true) return;
                    await overlayService.requestPermission();
                    return;
                  }
                }

                final ok = await notifier.toggleOverlay(value);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Grant overlay permission to enable the filter',
                      ),
                    ),
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.state,
    required this.isActive,
    required this.onToggle,
  });

  final AppState state;
  final bool isActive;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? 'Filter is ON' : 'Filter is OFF',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Preset: ${state.activePreset.name}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    _scheduleLabel(state.schedule),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Switch(value: state.overlayEnabled, onChanged: onToggle),
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
                    active: widget.state.overlayEnabled,
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
                          widget.onChanged(_SliderValues(temperature: value));
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
                          widget.onChanged(_SliderValues(opacity: value));
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
                          widget.onChanged(_SliderValues(brightness: value));
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
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.state, required this.onOpen});

  final AppState state;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    final schedule = state.schedule;

    return Card(
      child: ListTile(
        title: const Text('Schedule'),
        subtitle: Text(_subtitle(schedule)),
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
