class Deck {
  final int id;
  final int? subjectId;
  final String title;
  final int flashcardsCount;
  final DateTime createdAt;

  const Deck({
    required this.id,
    this.subjectId,
    required this.title,
    this.flashcardsCount = 0,
    required this.createdAt,
  });

  factory Deck.fromJson(Map<String, dynamic> json) {
    return Deck(
      id: json['id'] as int,
      subjectId: json['subject_id'] as int?,
      title: json['title'] as String,
      flashcardsCount: json['flashcards_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (subjectId != null) 'subject_id': subjectId,
    'title': title,
    'flashcards_count': flashcardsCount,
    'created_at': createdAt.toIso8601String(),
  };
}
