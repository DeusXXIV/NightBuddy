import 'package:flutter_test/flutter_test.dart';
import 'package:nightbuddy/utils/sleep_metrics.dart';

void main() {
  test('calculateSleepScore rewards duration, quality, and consistency', () {
    final score = calculateSleepScore(
      averageDuration: const Duration(hours: 8),
      averageQuality: 5,
      goalDuration: const Duration(hours: 8),
      bedtimeConsistency: 0,
    );

    expect(score, 100);
  });

  test('calculateSleepScore scales with lower duration and quality', () {
    final score = calculateSleepScore(
      averageDuration: const Duration(hours: 4),
      averageQuality: 2.5,
      goalDuration: const Duration(hours: 8),
    );

    expect(score, 40);
  });
}
