import 'package:flutter/material.dart';

import '../models/filter_models.dart';

class PresetChip extends StatelessWidget {
  const PresetChip({
    super.key,
    required this.preset,
    required this.selected,
    required this.onSelected,
    required this.isPremiumLocked,
  });

  final FilterPreset preset;
  final bool selected;
  final bool isPremiumLocked;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final locked = preset.isPremium && isPremiumLocked;
    return ChoiceChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(preset.name),
          if (preset.isPremium)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                locked ? Icons.lock_outline : Icons.workspace_premium,
                size: 16,
              ),
            ),
        ],
      ),
      onSelected: (_) => onSelected(),
      avatar: selected ? const Icon(Icons.check, size: 16) : null,
      showCheckmark: false,
      disabledColor: Colors.grey.shade800,
      backgroundColor: Colors.white.withAlpha((0.04 * 255).round()),
    );
  }
}
