import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/app_notifier.dart';
import '../../../state/app_state.dart';

const environmentCheckItems = <_EnvironmentCheckItem>[
  _EnvironmentCheckItem(
    id: 'lights',
    label: 'Lights are low',
    detail: 'Avoid bright overhead light before bed.',
    icon: Icons.lightbulb_outline,
  ),
  _EnvironmentCheckItem(
    id: 'temperature',
    label: 'Room feels comfortable',
    detail: 'Cool, quiet, and calm is the goal.',
    icon: Icons.thermostat_outlined,
  ),
  _EnvironmentCheckItem(
    id: 'alarm',
    label: 'Alarm is set',
    detail: 'No need to re-check it once you settle in.',
    icon: Icons.alarm_outlined,
  ),
  _EnvironmentCheckItem(
    id: 'bedside',
    label: 'Water and essentials nearby',
    detail: 'Reduce reasons to get back up.',
    icon: Icons.water_drop_outlined,
  ),
];

class EnvironmentCheckCard extends ConsumerWidget {
  const EnvironmentCheckCard({
    super.key,
    required this.state,
  });

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklist = state.environmentChecklistFor(DateTime.now());
    final completed = environmentCheckItems
        .where((item) => checklist[item.id] == true)
        .length;
    final allDone = completed == environmentCheckItems.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hotel_outlined),
                const SizedBox(width: 8),
                Text(
                  'Environment check',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              allDone
                  ? 'Room setup looks ready for tonight.'
                  : 'Quickly prep the room so you are not interrupted later.',
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
                _EnvironmentStatusChip(
                  label: 'Ready',
                  value: '$completed/${environmentCheckItems.length}',
                  active: allDone,
                ),
                _EnvironmentStatusChip(
                  label: 'Next',
                  value: _nextIncompleteLabel(checklist),
                  active: false,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EnvironmentCheckScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.chevron_right),
                label: Text(allDone ? 'Review room' : 'Open check'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _nextIncompleteLabel(Map<String, bool> checklist) {
    for (final item in environmentCheckItems) {
      if (checklist[item.id] != true) return item.label;
    }
    return 'Done';
  }
}

class EnvironmentCheckScreen extends ConsumerWidget {
  const EnvironmentCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider).valueOrNull ?? AppState.initial();
    final checklist = state.environmentChecklistFor(DateTime.now());
    final completed = environmentCheckItems
        .where((item) => checklist[item.id] == true)
        .length;
    final allDone = completed == environmentCheckItems.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Environment check'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(appStateProvider.notifier).resetEnvironmentChecklist();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Before bed, reduce small friction. Make the room feel settled so your body can follow.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: _mutedColor(context)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              allDone
                  ? 'Everything in tonight\'s room check is done.'
                  : 'Completed $completed of ${environmentCheckItems.length} checks.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          ...environmentCheckItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: CheckboxListTile(
                  value: checklist[item.id] == true,
                  onChanged: (value) {
                    ref
                        .read(appStateProvider.notifier)
                        .toggleEnvironmentCheckItem(item.id, value ?? false);
                  },
                  secondary: Icon(item.icon),
                  title: Text(item.label),
                  subtitle: Text(item.detail),
                  controlAffinity: ListTileControlAffinity.trailing,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentStatusChip extends StatelessWidget {
  const _EnvironmentStatusChip({
    required this.label,
    required this.value,
    required this.active,
  });

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: active ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
      backgroundColor: active
          ? scheme.primary.withValues(alpha: 0.12)
          : scheme.surfaceContainerHighest,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EnvironmentCheckItem {
  const _EnvironmentCheckItem({
    required this.id,
    required this.label,
    required this.detail,
    required this.icon,
  });

  final String id;
  final String label;
  final String detail;
  final IconData icon;
}

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
