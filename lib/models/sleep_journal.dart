class SleepJournalEntry {
  const SleepJournalEntry({
    required this.startedAt,
    required this.endedAt,
    required this.quality,
    required this.notes,
    required this.tags,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int quality;
  final String notes;
  final List<String> tags;

  Duration get duration {
    final diff = endedAt.difference(startedAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  Map<String, dynamic> toJson() {
    return {
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'quality': quality,
      'notes': notes,
      'tags': tags,
    };
  }

  factory SleepJournalEntry.fromJson(Map<String, dynamic> json) {
    final started = DateTime.tryParse(json['startedAt'] as String? ?? '');
    final ended = DateTime.tryParse(json['endedAt'] as String? ?? '');
    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags.whereType<String>().toList()
        : const <String>[];
    return SleepJournalEntry(
      startedAt: started ?? DateTime.now(),
      endedAt: ended ?? (started ?? DateTime.now()),
      quality: json['quality'] as int? ?? 3,
      notes: json['notes'] as String? ?? '',
      tags: tags,
    );
  }
}
