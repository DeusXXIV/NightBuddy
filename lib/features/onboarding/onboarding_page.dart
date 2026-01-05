// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/filter_models.dart';
import '../../state/app_notifier.dart';
import '../../state/app_state.dart';
import '../../services/overlay_service.dart';
import '../../services/log_service.dart';
import '../../widgets/preset_chip.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;
  FilterMode _initialMode = FilterMode.scheduled;
  bool _requestingPermission = false;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _bedtimeReminderEnabled = true;
  int _bedtimeReminderMinutes = 30;
  String? _selectedPresetId;
  bool _overlayGranted = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appStateProvider).value ?? AppState.initial();
    _initialMode = state.schedule.mode;
    _startTime = state.schedule.startTime ?? const TimeOfDay(hour: 22, minute: 0);
    _endTime = state.schedule.endTime ?? const TimeOfDay(hour: 6, minute: 0);
    _bedtimeReminderEnabled = state.bedtimeReminderEnabled;
    _bedtimeReminderMinutes = state.bedtimeReminderMinutes;
    _selectedPresetId = state.activePresetId;
    _refreshOverlayPermission();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider).value ?? AppState.initial();
    final pages = [
      _OnboardingCard(
        title: 'Welcome to NightBuddy',
        description:
            'Reduce blue light and keep your eyes comfortable at night.',
        icon: Icons.nightlight_round,
      ),
      _OnboardingCard(
        title: 'Warmer light, less strain',
        description: 'Switch to a warm tint that is easier on your eyes.',
        icon: Icons.wb_twilight,
      ),
      _overlayPermissionCard(context),
      _quickSetupCard(context, appState),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (value) => setState(() => _index = value),
                itemCount: pages.length,
                itemBuilder: (_, i) => pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      pages.length,
                      (i) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? Colors.orange
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      if (_index == 0) {
                        Navigator.of(context).maybePop();
                        return;
                      }
                      _controller.animateToPage(
                        (_index - 1).clamp(0, pages.length - 1),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _requestingPermission
                        ? null
                        : () async {
                            if (_index < pages.length - 1) {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                              return;
                            }
                            await _finishOnboarding();
                          },
                    child: Text(_index == pages.length - 1 ? 'Start' : 'Next'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _requestingPermission
                        ? null
                        : () async {
                            await _finishOnboarding(skipToEnd: true);
                          },
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overlayPermissionCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_outlined, size: 72),
          const SizedBox(height: 16),
          Text(
            'Enable overlay permission',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Required to tint your screen in other apps. We only draw a gentle color filter.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(
            _overlayGranted ? 'Permission granted' : 'Permission needed',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: _overlayGranted ? Colors.greenAccent : Colors.amber,
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _overlayGranted || _requestingPermission
                ? null
                : () async {
                    await _requestOverlayPermission();
                  },
            icon: const Icon(Icons.shield_outlined),
            label: Text(_overlayGranted ? 'Enabled' : 'Enable overlay'),
          ),
        ],
      ),
    );
  }

  Widget _quickSetupCard(BuildContext context, AppState state) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick setup',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Set your schedule, reminders, and preset for tonight.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Schedule mode',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            RadioListTile<FilterMode>(
              value: FilterMode.alwaysOn,
              groupValue: _initialMode,
              onChanged: (value) => setState(() => _initialMode = value!),
              title: const Text('Always on'),
            ),
            RadioListTile<FilterMode>(
              value: FilterMode.scheduled,
              groupValue: _initialMode,
              onChanged: (value) => setState(() => _initialMode = value!),
              title: const Text('Night schedule'),
            ),
            RadioListTile<FilterMode>(
              value: FilterMode.off,
              groupValue: _initialMode,
              onChanged: (value) => setState(() => _initialMode = value!),
              title: const Text('I will set it later'),
            ),
            if (_initialMode == FilterMode.scheduled) ...[
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Start time'),
                subtitle: Text(_formatTimeOfDay(_startTime)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _startTime,
                  );
                  if (picked != null) {
                    setState(() => _startTime = picked);
                  }
                },
              ),
              ListTile(
                title: const Text('End time'),
                subtitle: Text(_formatTimeOfDay(_endTime)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _endTime,
                  );
                  if (picked != null) {
                    setState(() => _endTime = picked);
                  }
                },
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bedtime reminder'),
              subtitle: Text(
                _initialMode == FilterMode.scheduled
                    ? 'Get a reminder before your schedule starts.'
                    : 'Enable a schedule to use reminders.',
              ),
              value: _initialMode == FilterMode.scheduled &&
                  _bedtimeReminderEnabled,
              onChanged: _initialMode == FilterMode.scheduled
                  ? (value) => setState(() => _bedtimeReminderEnabled = value)
                  : null,
            ),
            if (_initialMode == FilterMode.scheduled && _bedtimeReminderEnabled)
              Slider(
                min: 0,
                max: 120,
                divisions: 8,
                value: _bedtimeReminderMinutes.toDouble(),
                label: _bedtimeReminderMinutes == 0
                    ? 'At start'
                    : '$_bedtimeReminderMinutes min',
                onChanged: (value) =>
                    setState(() => _bedtimeReminderMinutes = value.round()),
              ),
            const SizedBox(height: 8),
            Text(
              'Preset',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.presets.map((preset) {
                final locked = preset.isPremium && !state.isPremium;
                final selected = preset.id == _selectedPresetId;
                return PresetChip(
                  preset: preset,
                  selected: selected,
                  isPremiumLocked: !state.isPremium,
                  onSelected: locked
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Premium preset - upgrade to unlock'),
                            ),
                          );
                        }
                      : () => setState(() => _selectedPresetId = preset.id),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _finishOnboarding({bool skipToEnd = false}) async {
    setState(() => _requestingPermission = true);
    final notifier = ref.read(appStateProvider.notifier);
    final current = ref.read(appStateProvider).value ?? AppState.initial();
    final overlayService = ref.read(overlayServiceProvider);
    final logService = ref.read(logServiceProvider);
    final schedule = current.schedule.copyWith(
      mode: _initialMode,
      startTime: _initialMode == FilterMode.scheduled ? _startTime : current.schedule.startTime,
      endTime: _initialMode == FilterMode.scheduled ? _endTime : current.schedule.endTime,
    );
    await notifier.updateSchedule(schedule);
    final enableReminder =
        _initialMode == FilterMode.scheduled && _bedtimeReminderEnabled;
    await notifier.toggleBedtimeReminder(enableReminder);
    if (enableReminder) {
      await notifier.setBedtimeReminderLeadMinutes(_bedtimeReminderMinutes);
    }
    if (_selectedPresetId != null) {
      await notifier.selectPreset(_selectedPresetId!);
    }
    await notifier.setOnboardingComplete();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final hasPermission = await overlayService.hasPermission();
      if (!hasPermission && mounted) {
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
        if (shouldOpen == true) {
          await overlayService.requestPermission();
          final granted = await overlayService.hasPermission();
          if (!granted) {
            await logService.logEvent(
              type: 'overlay_permission_denied',
              message: 'Overlay permission denied during onboarding.',
            );
          }
        }
      } else if (_initialMode != FilterMode.off) {
        await notifier.toggleOverlay(true);
      }
    });

    if (!mounted) return;
    if (skipToEnd) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _refreshOverlayPermission() async {
    final overlayService = ref.read(overlayServiceProvider);
    final granted = await overlayService.hasPermission();
    if (!mounted) return;
    setState(() => _overlayGranted = granted);
  }

  Future<void> _requestOverlayPermission() async {
    setState(() => _requestingPermission = true);
    final overlayService = ref.read(overlayServiceProvider);
    final logService = ref.read(logServiceProvider);
    await overlayService.requestPermission();
    final granted = await overlayService.hasPermission();
    if (!mounted) return;
    setState(() {
      _overlayGranted = granted;
      _requestingPermission = false;
    });
    if (!granted) {
      await logService.logEvent(
        type: 'overlay_permission_denied',
        message: 'Overlay permission denied during onboarding prompt.',
      );
    }
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
