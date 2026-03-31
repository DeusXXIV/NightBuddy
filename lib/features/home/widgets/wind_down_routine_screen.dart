import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/app_notifier.dart';
import '../../../state/app_state.dart';

class WindDownRoutineScreen extends ConsumerWidget {
  const WindDownRoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider).valueOrNull ?? AppState.initial();
    final notifier = ref.read(appStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Wind-down routine')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shape the steps you want before bed.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reorder, remove, or add steps until the routine feels natural each night.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your steps',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.windDownItems.isEmpty
                        ? 'No steps yet. Add the first one below.'
                        : 'Drag to reorder the steps you want to see each night.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (state.windDownItems.isEmpty)
                    Text(
                      'No steps yet.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _mutedColor(context),
                      ),
                    )
                  else
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: notifier.reorderWindDownItems,
                      children: [
                        for (final item in state.windDownItems)
                          ListTile(
                            key: ValueKey(item.id),
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.drag_handle),
                            title: Text(item.label),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  notifier.removeWindDownItem(item.id),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final label = await _showAddWindDownItemDialog(context);
                        if (label == null || label.trim().isEmpty) return;
                        await notifier.addWindDownItem(label);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add step'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
