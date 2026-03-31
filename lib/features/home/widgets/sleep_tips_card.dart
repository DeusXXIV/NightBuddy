import 'package:flutter/material.dart';

class SleepTipsCard extends StatelessWidget {
  const SleepTipsCard({super.key});

  static const _sections = [
    _SleepTipSection(
      title: 'Tonight',
      tips: [
        'Dim lights and screens 60 minutes before bed.',
        'Keep your room cool, dark, and quiet.',
        'Do a quick brain dump to offload thoughts.',
        'Avoid heavy meals right before sleep.',
      ],
    ),
    _SleepTipSection(
      title: 'Wind-down habits',
      tips: [
        'Stick to a consistent bedtime window.',
        'Use a low-stimulation activity (read, stretch, shower).',
        'Cut caffeine 6-8 hours before sleep.',
        'Avoid alcohol close to bedtime.',
      ],
    ),
    _SleepTipSection(
      title: 'Daytime anchors',
      tips: [
        'Get bright morning light within an hour of waking.',
        'Move your body daily, ideally earlier in the day.',
        'Keep naps short and early (20-30 minutes).',
        'Aim for a steady wake time, even on weekends.',
      ],
    ),
    _SleepTipSection(
      title: 'If you wake at night',
      tips: [
        'Keep lights low and avoid checking the time.',
        'Try a slow breathing pattern (4-6 seconds out).',
        'Get out of bed if you are awake for 20+ minutes.',
        'Return to bed when sleepy, not frustrated.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final previewTips =
        _sections.expand((section) => section.tips).take(3).toList();

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
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _SleepTipsScreen(
                      sections: _sections,
                    ),
                  ),
                ),
                child: const Text('More tips'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepTipSection {
  const _SleepTipSection({
    required this.title,
    required this.tips,
  });

  final String title;
  final List<String> tips;
}

class _SleepTipsScreen extends StatelessWidget {
  const _SleepTipsScreen({required this.sections});

  final List<_SleepTipSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep tips'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final section = sections[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...section.tips.map((tip) => _TipRow(text: tip)),
            ],
          );
        },
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
