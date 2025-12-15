import 'package:flutter/material.dart';

class AdBannerPlaceholder extends StatelessWidget {
  const AdBannerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      alignment: Alignment.center,
      child: Text(
        'Ad banner placeholder',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
