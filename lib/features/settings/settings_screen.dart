import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../constants/app_links.dart';
import '../../models/filter_models.dart';
import '../../state/app_notifier.dart';
import '../../services/bedtime_reminder_service.dart';
import '../../services/overlay_service.dart';
import '../../state/app_state.dart';
import '../../widgets/filter_preview_overlay.dart';
import '../schedule/schedule_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    return appState.when(
      data: (state) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          children: [
            SwitchListTile(
              title: const Text('Show notification shortcut'),
              subtitle: const Text('Quick toggle to disable or enable filter'),
              value: state.notificationShortcutEnabled,
              onChanged: (value) {
                ref
                    .read(appStateProvider.notifier)
                    .toggleNotificationShortcut(value);
              },
            ),
            SwitchListTile(
              title: const Text('Start on boot reminder'),
              subtitle: const Text(
                'Show reminder to enable overlay after reboot',
              ),
              value: state.startOnBootReminder,
              onChanged: (value) {
                ref
                    .read(appStateProvider.notifier)
                    .toggleStartOnBootReminder(value);
              },
            ),
            SwitchListTile(
              title: const Text('High contrast mode'),
              subtitle: const Text('Boost contrast for low-light readability.'),
              value: state.highContrastEnabled,
              onChanged: (value) {
                ref
                    .read(appStateProvider.notifier)
                    .toggleHighContrast(value);
              },
            ),
            SwitchListTile(
              title: const Text('Bedtime reminders'),
              subtitle: Text(
                state.schedule.mode == FilterMode.scheduled
                    ? 'Get a reminder before your schedule starts'
                    : 'Enable a schedule to use reminders',
              ),
              value: state.bedtimeReminderEnabled,
              onChanged: (value) async {
                if (value && state.schedule.mode != FilterMode.scheduled) {
                  await _promptScheduleSetup(context);
                  return;
                }
                ref
                    .read(appStateProvider.notifier)
                    .toggleBedtimeReminder(value);
              },
            ),
            if (state.bedtimeReminderEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminder lead time',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      'Notify this many minutes before the schedule starts.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      min: 0,
                      max: 120,
                      divisions: 8,
                      value: state.bedtimeReminderMinutes.toDouble(),
                      label: state.bedtimeReminderMinutes == 0
                          ? 'At start'
                          : '${state.bedtimeReminderMinutes} min',
                      onChanged: (value) {
                        ref
                            .read(appStateProvider.notifier)
                            .setBedtimeReminderLeadMinutes(value.round());
                      },
                    ),
                  ],
                ),
              ),
            SwitchListTile(
              title: const Text('Morning check-in reminder'),
              subtitle: const Text('Daily prompt to log your sleep quality'),
              value: state.sleepCheckInEnabled,
              onChanged: (value) {
                ref
                    .read(appStateProvider.notifier)
                    .toggleSleepCheckInReminder(value);
              },
            ),
            if (state.sleepCheckInEnabled)
              ListTile(
                title: const Text('Check-in time'),
                subtitle: Text(_formatTimeOfDay(state.sleepCheckInTime)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final result = await showTimePicker(
                    context: context,
                    initialTime: state.sleepCheckInTime,
                  );
                  if (!context.mounted || result == null) return;
                  ref
                      .read(appStateProvider.notifier)
                      .setSleepCheckInTime(result);
                },
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _NotificationScheduleCard(state: state),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Blue-light goal',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Minutes of warm filter time before bed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    min: 30,
                    max: 240,
                    divisions: 7,
                    value: state.blueLightGoalMinutes.toDouble(),
                    label: _formatGoalMinutes(state.blueLightGoalMinutes),
                    onChanged: (value) {
                      ref
                          .read(appStateProvider.notifier)
                          .setBlueLightGoalMinutes(value.round());
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final minutes in const [60, 90, 120, 150])
                        OutlinedButton(
                          onPressed: () {
                            ref
                                .read(appStateProvider.notifier)
                                .setBlueLightGoalMinutes(minutes);
                          },
                          child: Text(_formatGoalMinutes(minutes)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Screen-off goal',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Default no-phone window before bed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    min: 15,
                    max: 180,
                    divisions: 11,
                    value: state.screenOffGoalMinutes.toDouble(),
                    label: _formatGoalMinutes(state.screenOffGoalMinutes),
                    onChanged: (value) {
                      ref
                          .read(appStateProvider.notifier)
                          .setScreenOffGoalMinutes(value.round());
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final minutes in const [30, 60, 90])
                        OutlinedButton(
                          onPressed: () {
                            ref
                                .read(appStateProvider.notifier)
                                .setScreenOffGoalMinutes(minutes);
                          },
                          child: Text(_formatGoalMinutes(minutes)),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Screen-off notifications'),
                    subtitle: const Text('Notify when the no-phone window starts/ends.'),
                    value: state.screenOffNotificationsEnabled,
                    onChanged: (value) {
                      ref
                          .read(appStateProvider.notifier)
                          .toggleScreenOffNotifications(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Caffeine cutoff',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Warn this many hours before bedtime.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    min: 2,
                    max: 12,
                    divisions: 10,
                    value: state.caffeineCutoffHours.toDouble(),
                    label: '${state.caffeineCutoffHours}h',
                    onChanged: (value) {
                      ref
                          .read(appStateProvider.notifier)
                          .setCaffeineCutoffHours(value.round());
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final hours in const [4, 6, 8])
                        OutlinedButton(
                          onPressed: () {
                            ref
                                .read(appStateProvider.notifier)
                                .setCaffeineCutoffHours(hours);
                          },
                          child: Text('${hours}h'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sleep goal',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Set your nightly sleep target.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    min: 240,
                    max: 720,
                    divisions: 16,
                    value: state.sleepGoalMinutes.toDouble(),
                    label: _formatGoalMinutes(state.sleepGoalMinutes),
                    onChanged: (value) {
                      ref
                          .read(appStateProvider.notifier)
                          .setSleepGoalMinutes(value.round());
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Wind-down checklist',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Customize the steps you want to complete each night.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (state.windDownItems.isEmpty)
                    Text(
                      'No items yet. Add your first step.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: _mutedColor(context)),
                    )
                  else
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        ref
                            .read(appStateProvider.notifier)
                            .reorderWindDownItems(oldIndex, newIndex);
                      },
                      children: [
                        for (final item in state.windDownItems)
                          ListTile(
                            key: ValueKey(item.id),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.label),
                            leading: const Icon(Icons.drag_handle),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                ref
                                    .read(appStateProvider.notifier)
                                    .removeWindDownItem(item.id);
                              },
                            ),
                          ),
                      ],
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final label = await _showAddWindDownItemDialog(context);
                        if (label == null || label.trim().isEmpty) return;
                        await ref
                            .read(appStateProvider.notifier)
                            .addWindDownItem(label);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add step'),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Bedtime mode preset'),
              subtitle: const Text(
                'Select the preset used when starting bedtime mode.',
              ),
              trailing: DropdownButton<String?>(
                value: state.bedtimeModePresetId,
                underline: const SizedBox.shrink(),
                onChanged: (value) {
                  if (value != null) {
                    final preset = state.presets.firstWhere(
                      (item) => item.id == value,
                      orElse: () => state.activePreset,
                    );
                    if (preset.isPremium && !state.isPremium) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Premium preset - upgrade to unlock'),
                        ),
                      );
                      return;
                    }
                  }
                  ref
                      .read(appStateProvider.notifier)
                      .setBedtimeModePresetId(value);
                },
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Use current preset'),
                  ),
                  ...state.presets.map((preset) {
                    final label = preset.isPremium && !state.isPremium
                        ? '${preset.name} (Premium)'
                        : preset.name;
                    return DropdownMenuItem<String?>(
                      value: preset.id,
                      enabled: state.isPremium || !preset.isPremium,
                      child: Text(label),
                    );
                  }),
                ],
              ),
            ),
            if (!state.isPremium)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Premium presets are locked for bedtime mode.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _BedtimePresetPreview(state: state),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _CustomPresetsSection(state: state),
            ),
            SwitchListTile(
              title: const Text('Bedtime mode starts screen-off goal'),
              subtitle: const Text('Begin the no-phone window automatically.'),
              value: state.bedtimeModeStartScreenOff,
              onChanged: (value) {
                ref
                    .read(appStateProvider.notifier)
                    .toggleBedtimeModeStartScreenOff(value);
              },
            ),
            ListTile(
              title: const Text('Bedtime mode auto-off'),
              subtitle: Text(
                state.bedtimeModeAutoOffMinutes == 0
                    ? 'Keep filter on until you turn it off'
                    : 'Auto-off after ${_formatGoalMinutes(state.bedtimeModeAutoOffMinutes)}',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Slider(
                min: 0,
                max: 180,
                divisions: 12,
                value: state.bedtimeModeAutoOffMinutes.toDouble(),
                label: state.bedtimeModeAutoOffMinutes == 0
                    ? 'Off'
                    : _formatGoalMinutes(state.bedtimeModeAutoOffMinutes),
                onChanged: (value) {
                  ref
                      .read(appStateProvider.notifier)
                      .setBedtimeModeAutoOffMinutes(value.round());
                },
              ),
            ),
            SwitchListTile(
              title: const Text('Sunset sync'),
              subtitle: const Text('Use location-based sunset time for planning.'),
              value: state.sunsetSyncEnabled,
              onChanged: (value) {
                ref.read(appStateProvider.notifier).toggleSunsetSync(value);
              },
            ),
            _OverlayPermissionRow(),
            _FlashlightToggle(state: state),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Export sleep journal (CSV)'),
              subtitle: const Text('Share your sleep logs'),
              onTap: () => _exportSleepJournalCsv(context, state),
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('Clear sleep journal'),
              subtitle: const Text('Remove all logged sleep entries'),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear sleep journal'),
                    content: const Text(
                      'This will remove all saved sleep journal entries.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(appStateProvider.notifier).clearSleepJournal();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sleep journal cleared')),
                  );
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text('Rate this app'),
              onTap: () {
                _launchUrl(
                  'market://details?id=$kAndroidPackageId',
                  context,
                  fallback:
                      'https://play.google.com/store/apps/details?id=$kAndroidPackageId',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () => _handleLegalTap(
                context,
                url: kPrivacyPolicyUrl,
                fallbackTitle: 'Privacy Policy',
                fallbackBody:
                    'NightBuddy stores your preferences (presets, schedule, premium flag) locally on your device only. No personal data is sent to our servers. '
                    'Ads and in-app purchases may collect diagnostics per their respective SDK policies. You can clear app data to reset stored preferences.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Terms of Service'),
              onTap: () => _handleLegalTap(
                context,
                url: kTermsOfServiceUrl,
                fallbackTitle: 'Terms of Service',
                fallbackBody:
                    'Use NightBuddy at your own discretion. The app provides a screen tint overlay to reduce blue light. We do not guarantee medical outcomes. '
                    'By using the app, you agree not to misuse overlays (e.g., to obscure critical system dialogs) and to comply with Play Store policies. '
                    'Premium unlock is non-transferable and subject to Play Store billing terms.',
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'NightBuddy reduces blue light by tinting your screen with a warm overlay. '
                'Use it at night to help your eyes relax.',
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 24),
              child: Text('Version 0.1.0'),
            ),
          ],
        ),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

String _formatGoalMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (mins == 0) return '${hours}h';
  return '${hours}h ${mins}m';
}

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

Future<void> _promptScheduleSetup(BuildContext context) async {
  final shouldOpen = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Set a schedule'),
      content: const Text(
        'Bedtime reminders follow your schedule. Set a schedule to continue.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Set schedule'),
        ),
      ],
    ),
  );
  if (shouldOpen == true && context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScheduleScreen()),
    );
  }
}

Future<String?> _showAddWindDownItemDialog(BuildContext context) async {        
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add wind-down step'),
      content: TextField(
        controller: controller,
        maxLength: 40,
        decoration: const InputDecoration(
          labelText: 'Step label',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('Add'),
        ),
      ],
    ),
  );
}

Future<String?> _showCustomPresetNameDialog(
  BuildContext context, {
  required String initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Custom preset name'),
      content: TextField(
        controller: controller,
        maxLength: 24,
        decoration: const InputDecoration(
          labelText: 'Preset name',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmDeletePreset(
  BuildContext context,
  String name,
) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete custom preset'),
      content: Text('Delete "$name"? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

Future<void> _exportSleepJournalCsv(BuildContext context, AppState state) async {
  if (state.sleepJournalEntries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No sleep entries to export')),
    );
    return;
  }
  final buffer = StringBuffer('started_at,ended_at,quality,notes\n');
  for (final entry in state.sleepJournalEntries) {
    buffer
      ..write(_csvEscape(entry.startedAt.toIso8601String()))
      ..write(',')
      ..write(_csvEscape(entry.endedAt.toIso8601String()))
      ..write(',')
      ..write(entry.quality.toString())
      ..write(',')
      ..write(_csvEscape(entry.notes))
      ..write('\n');
  }
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/nightbuddy_sleep_journal.csv');
  await file.writeAsString(buffer.toString());
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: 'NightBuddy sleep journal',
  );
}

String _csvEscape(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

Future<void> _handleLegalTap(
  BuildContext context, {
  required String url,
  required String fallbackTitle,
  required String fallbackBody,
}) async {
  if (url.isNotEmpty) {
    await _launchUrl(url, context);
    return;
  }
  _showLegal(context, title: fallbackTitle, body: fallbackBody);
}

Future<void> _launchUrl(String url, BuildContext context,
    {String? fallback}) async {
  final can = await canLaunchUrlString(url);
  if (can) {
    await launchUrlString(url, mode: LaunchMode.externalApplication);
    return;
  }
  if (fallback != null && await canLaunchUrlString(fallback)) {
    await launchUrlString(fallback, mode: LaunchMode.externalApplication);
    return;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open link')),
    );
  }
}

void _showLegal(BuildContext context,
    {required String title, required String body}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  body,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OverlayPermissionRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    return appState.when(
      data: (_) => _OverlayPermissionContent(),
      loading: () => const ListTile(
        leading: Icon(Icons.layers),
        title: Text('Overlay permission'),
        subtitle: Text('Checking permission...'),
      ),
      error: (error, _) => const SizedBox.shrink(),
    );
  }
}

class _OverlayPermissionContent extends ConsumerStatefulWidget {
  @override
  ConsumerState<_OverlayPermissionContent> createState() =>
      _OverlayPermissionContentState();
}

class _OverlayPermissionContentState
    extends ConsumerState<_OverlayPermissionContent> {
  bool? _granted;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final service = ref.read(overlayServiceProvider);
    final has = await service.hasPermission();
    if (!mounted) return;
    setState(() {
      _granted = has;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final icon = _granted == true ? Icons.check_circle : Icons.error_outline;
    final color = _granted == true ? Colors.greenAccent : Colors.amber;
    final subtitle = _granted == true
        ? 'Permission granted'
        : 'Tap to open system overlay settings';

    return ListTile(
      leading: Icon(Icons.layers, color: color),
      title: const Text('Overlay permission'),
      subtitle: _loading ? const Text('Checking...') : Text(subtitle),
      trailing: Icon(icon, color: color),
      onTap: () async {
        final overlayService = ref.read(overlayServiceProvider);
        if (_granted == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Overlay permission already granted')),
          );
          return;
        }
        await overlayService.requestPermission();
        if (!mounted) return;
        await _refresh();
      },
    );
  }
}

class _FlashlightToggle extends ConsumerWidget {
  const _FlashlightToggle({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(flashlightAvailableProvider);
    return availability.when(
      data: (hasFlash) => SwitchListTile(
        title: const Text('Flashlight shortcut'),
        subtitle: Text(
          hasFlash
              ? 'Allow quick torch toggle from NightBuddy'
              : 'Not available on this device',
        ),
        value: hasFlash ? state.flashlightEnabled : false,
        onChanged: hasFlash
            ? (value) async {
                final ok = await ref
                    .read(appStateProvider.notifier)
                    .toggleFlashlight(value);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Flashlight unavailable or permission denied'),
                    ),
                  );
                }
              }
            : null,
      ),
      loading: () => const ListTile(
        leading: CircularProgressIndicator(strokeWidth: 2),
        title: Text('Flashlight shortcut'),
        subtitle: Text('Checking availability...'),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}

class _BedtimePresetPreview extends StatelessWidget {
  const _BedtimePresetPreview({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final presetId = state.bedtimeModePresetId ?? state.activePresetId;
    final preset = state.presets.firstWhere(
      (item) => item.id == presetId,
      orElse: () => state.activePreset,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preset preview',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 2.2,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FilterPreviewOverlay(
                  preset: preset,
                  active: true,
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    preset.name,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomPresetsSection extends ConsumerWidget {
  const _CustomPresetsSection({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customPresets =
        state.presets.where((preset) => preset.isCustom).toList();
    final nextName = 'Custom ${customPresets.length + 1}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom presets',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Save and manage multiple custom filters.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 8),
            if (customPresets.isEmpty)
              Text(
                'No custom presets yet.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              )
            else
              Column(
                children: [
                  for (final preset in customPresets)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(preset.name),
                      subtitle: Text(
                        'Temp ${preset.temperature.toStringAsFixed(0)}, '
                        'Opacity ${preset.opacity.toStringAsFixed(0)}, '
                        'Brightness ${preset.brightness.toStringAsFixed(0)}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'rename') {
                            final name = await _showCustomPresetNameDialog(
                              context,
                              initialValue: preset.name,
                            );
                            if (name == null) return;
                            await ref
                                .read(appStateProvider.notifier)
                                .renameCustomPreset(preset.id, name);
                          } else if (value == 'delete') {
                            final confirm = await _confirmDeletePreset(
                              context,
                              preset.name,
                            );
                            if (confirm != true) return;
                            await ref
                                .read(appStateProvider.notifier)
                                .deleteCustomPreset(preset.id);
                          }
                        },
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                      onTap: () async {
                        await ref
                            .read(appStateProvider.notifier)
                            .selectPreset(preset.id);
                      },
                    ),
                ],
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final name = await _showCustomPresetNameDialog(
                    context,
                    initialValue: nextName,
                  );
                  if (name == null) return;
                  await ref.read(appStateProvider.notifier).addCustomPreset(
                        name: name,
                        basePreset: state.activePreset,
                      );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add custom preset'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationScheduleCard extends ConsumerWidget {
  const _NotificationScheduleCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final bedtimeEnabled =
        state.bedtimeReminderEnabled && state.schedule.mode == FilterMode.scheduled;
    final nextBedtime = _nextBedtimeReminder(
      state.schedule,
      state.bedtimeReminderMinutes,
      now,
    );
    final bedtimeLabel = bedtimeEnabled
        ? (nextBedtime != null
            ? 'Next: ${_formatDateTime(nextBedtime)}'
            : 'No upcoming reminder')
        : (state.schedule.mode != FilterMode.scheduled
            ? 'Enable a schedule to use reminders'
            : 'Off');

    final checkInEnabled = state.sleepCheckInEnabled;
    final nextCheckIn = _nextTimeOfDay(state.sleepCheckInTime, now);
    final checkInLabel = checkInEnabled
        ? 'Next: ${_formatDateTime(nextCheckIn)}'
        : 'Off';

    final screenOffEnabled = state.screenOffNotificationsEnabled;
    final screenOffLabel = screenOffEnabled
        ? (state.screenOffUntil != null && state.screenOffUntil!.isAfter(now)
            ? 'Active until ${_formatDateTime(state.screenOffUntil!)}'
            : 'On when you start a screen-off goal')
        : 'Off';

    Future<void> sendPreview(NotificationPreview type, String label) async {
      await ref.read(bedtimeReminderServiceProvider).showPreview(type);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label sent')),
      );
    }

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Notification schedule'),
            subtitle: Text(
              'See what is coming next.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Bedtime reminder'),
            subtitle: Text(bedtimeLabel),
            trailing: TextButton(
              onPressed: bedtimeEnabled
                  ? () => sendPreview(
                        NotificationPreview.bedtime,
                        'Bedtime preview',
                      )
                  : null,
              child: const Text('Preview'),
            ),
          ),
          ListTile(
            title: const Text('Morning check-in'),
            subtitle: Text(checkInLabel),
            trailing: TextButton(
              onPressed: checkInEnabled
                  ? () => sendPreview(
                        NotificationPreview.checkIn,
                        'Check-in preview',
                      )
                  : null,
              child: const Text('Preview'),
            ),
          ),
          ListTile(
            title: const Text('Screen-off goal'),
            subtitle: Text(screenOffLabel),
            trailing: TextButton(
              onPressed: screenOffEnabled
                  ? () => sendPreview(
                        NotificationPreview.screenOff,
                        'Screen-off preview',
                      )
                  : null,
              child: const Text('Preview'),
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _nextBedtimeReminder(
  ScheduleConfig schedule,
  int leadMinutes,
  DateTime now,
) {
  if (schedule.mode != FilterMode.scheduled) return null;
  final baseStart = schedule.startTime;
  if (baseStart == null) return null;
  DateTime? candidate;
  for (var offset = 0; offset <= 7; offset++) {
    final day = now.add(Duration(days: offset));
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final startTime = schedule.weekendDifferent && isWeekend
        ? (schedule.weekendStartTime ?? baseStart)
        : baseStart;
    final startDate = DateTime(
      day.year,
      day.month,
      day.day,
      startTime.hour,
      startTime.minute,
    );
    final reminder = startDate.subtract(Duration(minutes: leadMinutes));
    if (reminder.isAfter(now) &&
        (candidate == null || reminder.isBefore(candidate))) {
      candidate = reminder;
    }
  }
  return candidate;
}

DateTime _nextTimeOfDay(TimeOfDay time, DateTime now) {
  var candidate =
      DateTime(now.year, now.month, now.day, time.hour, time.minute);
  if (!candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}

String _formatDateTime(DateTime time) {
  const weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  final weekday = weekdays[time.weekday - 1];
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  return '$weekday, $hour:$minute $period';
}
