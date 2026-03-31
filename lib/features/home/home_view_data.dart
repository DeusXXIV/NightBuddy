import '../../models/mind_unload_entry.dart';
import '../../services/sleep_audio_service.dart';
import '../../state/app_state.dart';
import 'widgets/environment_check_card.dart';

class HomeViewData {
  const HomeViewData({
    required this.isFilterActive,
    required this.snoozedUntil,
    required this.bedtimeProgress,
    required this.isReadyForTonight,
    required this.liveAudioSummary,
    required this.trackingSummary,
    required this.carryOverEntry,
    required this.extrasSummary,
    required this.shouldEnableOverlay,
  });

  final bool isFilterActive;
  final DateTime? snoozedUntil;
  final int bedtimeProgress;
  final bool isReadyForTonight;
  final String liveAudioSummary;
  final String trackingSummary;
  final MindUnloadEntry? carryOverEntry;
  final String extrasSummary;
  final bool shouldEnableOverlay;
}

HomeViewData buildHomeViewData({
  required AppState state,
  required SleepAudioController audio,
  required DateTime now,
}) {
  final sleepJournalActiveStart = state.sleepJournalActiveStart;
  final sleepJournalEntries = state.sleepJournalEntries;
  final roomReady =
      state.environmentChecklistFor(now).length == environmentCheckItems.length &&
      environmentCheckItems.every(
        (item) => state.environmentChecklistFor(now)[item.id] == true,
      );
  final mindClear = state.mindUnloadEntries.where((entry) => !entry.resolved).isEmpty;
  final isFilterActive = state.isFilterActive(now);
  final phoneDownStarted = state.screenOffUntil != null;
  final bedtimeProgress = [
    roomReady,
    mindClear,
    isFilterActive,
    phoneDownStarted,
  ].where((done) => done).length;

  const sleepTrackLabels = {
    'drift': 'Rainbound Lullaby',
    'fan': 'Velvet Fan Drift',
    'ocean': 'Oceannight Repose',
  };

  final favoriteTrackLabel =
      sleepTrackLabels[state.favoriteSleepTrackId] ?? 'Rainbound Lullaby';
  final defaultAudioSummary =
      'Favorite $favoriteTrackLabel • ${_formatTimerLabel(state.preferredSleepTimerMinutes)} timer';
  final activeTrackLabel = sleepTrackLabels[audio.activeTrackId];
  final audioRemaining = audio.endTime?.difference(now);
  final liveAudioSummary = activeTrackLabel != null
      ? audioRemaining != null && !audioRemaining.isNegative
            ? 'Playing $activeTrackLabel • ${_formatDurationCompact(audioRemaining)} left'
            : 'Playing $activeTrackLabel'
      : defaultAudioSummary;

  final trackingSummary = sleepJournalEntries.isEmpty
      ? 'No entries yet • quick log available'
      : sleepJournalActiveStart != null
      ? 'Sleep session in progress'
      : 'Latest ${_formatDurationCompact(sleepJournalEntries.first.duration)} • ${sleepJournalEntries.length} logged';

  final carryOverEntry = state.mindUnloadEntries
      .where((entry) => !entry.resolved && !_isSameLocalDay(entry.createdAt, now))
      .cast<MindUnloadEntry?>()
      .firstWhere((entry) => entry != null, orElse: () => null);

  final extrasSummary = bedtimeProgress == 4
      ? 'Everything else is optional tonight'
      : state.screenOffUntil != null
      ? 'Phone-down is active • extras available if needed'
      : 'Caffeine cutoff, blue-light goal, flashlight, and tips';

  return HomeViewData(
    isFilterActive: isFilterActive,
    snoozedUntil: state.snoozeUntil,
    bedtimeProgress: bedtimeProgress,
    isReadyForTonight: bedtimeProgress == 4,
    liveAudioSummary: liveAudioSummary,
    trackingSummary: trackingSummary,
    carryOverEntry: carryOverEntry,
    extrasSummary: extrasSummary,
    shouldEnableOverlay: state.filterEnabled && !state.isSnoozed(now),
  );
}

String _formatTimerLabel(int minutes) {
  if (minutes % 60 == 0) {
    return '${minutes ~/ 60}h';
  }
  return '${minutes}m';
}

String _formatDurationCompact(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours <= 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

bool _isSameLocalDay(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}
