import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/mind_unload_entry.dart';
import '../../../state/app_notifier.dart';
import '../../../state/app_state.dart';

const mindUnloadCategories = [
  'Thought',
  'Worry',
  'Reminder',
  'Gratitude',
];

class MindUnloadCard extends ConsumerWidget {
  const MindUnloadCard({
    super.key,
    required this.entries,
  });

  final List<MindUnloadEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final tonightEntries = entries
        .where((entry) => _isSameDay(entry.createdAt.toLocal(), now))
        .length;
    final pendingCount = entries.where((entry) => !entry.resolved).length;
    final latest = entries.isEmpty ? null : entries.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_alt_outlined),
                const SizedBox(width: 8),
                Text(
                  'Mind unload',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              latest == null
                  ? 'Clear your head before bed. Capture worries, reminders, or loose thoughts.'
                  : 'Pending: $pendingCount | Logged tonight: $tonightEntries',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            if (latest != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest.category,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      latest.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MindUnloadScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_note_outlined),
                label: Text(latest == null ? 'Open mind unload' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MindUnloadScreen extends ConsumerStatefulWidget {
  const MindUnloadScreen({super.key});

  @override
  ConsumerState<MindUnloadScreen> createState() => _MindUnloadScreenState();
}

class _MindUnloadScreenState extends ConsumerState<MindUnloadScreen> {
  final TextEditingController _controller = TextEditingController();
  String _selectedCategory = mindUnloadCategories.first;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await ref.read(appStateProvider.notifier).addMindUnloadEntry(
      text: text,
      category: _selectedCategory,
    );
    if (!mounted) return;
    _controller.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to mind unload')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider).valueOrNull ?? AppState.initial();
    final entries = state.mindUnloadEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mind unload'),
        actions: [
          if (entries.any((entry) => entry.resolved))
            TextButton(
              onPressed: () async {
                await ref
                    .read(appStateProvider.notifier)
                    .clearResolvedMindUnloadEntries();
              },
              child: const Text('Clear done'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Get it out of your head before bed. Capture what is looping so your night can be quieter.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: _mutedColor(context)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 5,
            maxLength: 220,
            decoration: const InputDecoration(
              labelText: 'What is on your mind?',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mindUnloadCategories.map((category) {
              return ChoiceChip(
                label: Text(category),
                selected: _selectedCategory == category,
                onSelected: (_) {
                  setState(() => _selectedCategory = category);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save thought'),
            ),
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Nothing saved yet. Use this space for reminders, worries, or things you do not want to keep rehearsing tonight.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MindUnloadEntryTile(entry: entry),
              ),
            ),
        ],
      ),
    );
  }
}

class _MindUnloadEntryTile extends ConsumerWidget {
  const _MindUnloadEntryTile({required this.entry});

  final MindUnloadEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Checkbox(
          value: entry.resolved,
          onChanged: (_) {
            ref.read(appStateProvider.notifier).toggleMindUnloadResolved(entry.id);
          },
        ),
        title: Text(
          entry.text,
          style: entry.resolved
              ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: _mutedColor(context),
                  )
              : null,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                label: Text(entry.category),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                _formatTimestamp(entry.createdAt.toLocal()),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          onPressed: () {
            ref.read(appStateProvider.notifier).removeMindUnloadEntry(entry.id);
          },
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  return '${time.month}/${time.day} $hour:$minute $period';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
