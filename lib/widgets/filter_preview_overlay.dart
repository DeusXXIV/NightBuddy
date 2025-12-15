import 'package:flutter/material.dart';

import '../models/filter_models.dart';

class FilterPreviewOverlay extends StatelessWidget {
  const FilterPreviewOverlay({
    super.key,
    required this.preset,
    required this.active,
  });

  final FilterPreset preset;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final warmth = (preset.temperature.clamp(0, 100) / 100).toDouble();
    final tint = Color.lerp(Colors.white, Colors.deepOrange, warmth);
    final dimOpacity = (1 - (preset.brightness.clamp(0, 100) / 100))
        .clamp(0.0, 0.65)
        .toDouble();
    final overlayOpacity = ((preset.opacity.clamp(0, 100) / 100))
        .clamp(0.0, 0.85)
        .toDouble();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: active ? 1 : 0,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: tint?.withAlpha((overlayOpacity * 255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          if (dimOpacity > 0)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((dimOpacity * 255).round()),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
        ],
      ),
    );
  }
}
