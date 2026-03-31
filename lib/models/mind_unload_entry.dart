class MindUnloadEntry {
  const MindUnloadEntry({
    required this.id,
    required this.createdAt,
    required this.text,
    required this.category,
    this.resolved = false,
  });

  final String id;
  final DateTime createdAt;
  final String text;
  final String category;
  final bool resolved;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'text': text,
      'category': category,
      'resolved': resolved,
    };
  }

  factory MindUnloadEntry.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    return MindUnloadEntry(
      id: json['id'] as String? ?? '',
      createdAt: createdAt ?? DateTime.now(),
      text: json['text'] as String? ?? '',
      category: json['category'] as String? ?? 'Thought',
      resolved: json['resolved'] as bool? ?? false,
    );
  }

  MindUnloadEntry copyWith({
    String? id,
    DateTime? createdAt,
    String? text,
    String? category,
    bool? resolved,
  }) {
    return MindUnloadEntry(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      text: text ?? this.text,
      category: category ?? this.category,
      resolved: resolved ?? this.resolved,
    );
  }
}
