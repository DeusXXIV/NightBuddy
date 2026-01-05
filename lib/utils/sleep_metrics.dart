int calculateSleepScore({
  required Duration averageDuration,
  required double averageQuality,
  required Duration goalDuration,
  double? bedtimeConsistency,
}) {
  final goalMinutes = goalDuration.inMinutes.clamp(1, 10000);
  final durationRatio =
      (averageDuration.inMinutes / goalMinutes).clamp(0.0, 1.0);
  final durationScore = 50 * durationRatio;
  final qualityScore = 30 * (averageQuality / 5).clamp(0.0, 1.0);
  final consistencyScore = bedtimeConsistency == null
      ? 0.0
      : 20 * (1 - (bedtimeConsistency / 90)).clamp(0.0, 1.0);
  return (durationScore + qualityScore + consistencyScore).round();
}
