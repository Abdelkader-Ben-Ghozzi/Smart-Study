// ── CourseSource ──────────────────────────────────────────────────────────────
class CourseSource {
  final int id;
  final int courseId;
  final String name;
  final String type; // 'pdf' | 'docx' | 'image' | 'other'
  final String mimeType;
  final int size;
  final String url;
  final DateTime createdAt;

  const CourseSource({
    required this.id,
    required this.courseId,
    required this.name,
    required this.type,
    required this.mimeType,
    required this.size,
    required this.url,
    required this.createdAt,
  });

  factory CourseSource.fromJson(Map<String, dynamic> json) {
    return CourseSource(
      id: json['id'] as int,
      courseId: json['course_id'] as int,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'other',
      mimeType: json['mime_type'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1048576).toStringAsFixed(1)} MB';
  }
}

// ── GeneratedContent ──────────────────────────────────────────────────────────
enum AiTool { flashcards, summary, qcm }

extension AiToolExt on AiTool {
  String get name => switch (this) {
    AiTool.flashcards => 'flashcards',
    AiTool.summary => 'summary',
    AiTool.qcm => 'qcm',
  };
  String get label => switch (this) {
    AiTool.flashcards => 'Flashcards',
    AiTool.summary => 'Summary',
    AiTool.qcm => 'QCM / Quiz',
  };

  static AiTool fromString(String s) => switch (s) {
    'flashcards' => AiTool.flashcards,
    'summary' => AiTool.summary,
    _ => AiTool.qcm,
  };
}

class GeneratedContent {
  final int id;
  final int courseId;
  final AiTool tool;
  final String title;
  final Map<String, dynamic> content;
  final Map<String, dynamic>? options;
  final DateTime createdAt;

  const GeneratedContent({
    required this.id,
    required this.courseId,
    required this.tool,
    required this.title,
    required this.content,
    this.options,
    required this.createdAt,
  });

  factory GeneratedContent.fromJson(Map<String, dynamic> json) {
    return GeneratedContent(
      id: json['id'] as int,
      courseId: json['course_id'] as int,
      tool: AiToolExt.fromString(json['tool'] as String),
      title: json['title'] as String? ?? '',
      content: Map<String, dynamic>.from(json['content'] as Map),
      options: json['options'] != null
          ? Map<String, dynamic>.from(json['options'] as Map)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // ── Typed accessors ──────────────────────────────────────────────────────

  List<Flashcard> get flashcards {
    final list = content['flashcards'] as List? ?? [];
    return list
        .map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Summary? get summary {
    final s = content['summary'];
    if (s == null) return null;
    return Summary.fromJson(s as Map<String, dynamic>);
  }

  List<QcmQuestion> get questions {
    final list = content['questions'] as List? ?? [];
    return list
        .map((e) => QcmQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ── Flashcard ─────────────────────────────────────────────────────────────────
class Flashcard {
  final int id;
  final String front;
  final String back;

  const Flashcard({required this.id, required this.front, required this.back});

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
    id: json['id'] as int? ?? 0,
    front: json['front'] as String,
    back: json['back'] as String,
  );
}

// ── Summary ───────────────────────────────────────────────────────────────────
class Summary {
  final String title;
  final String overview;
  final List<String> keyPoints;
  final List<SummarySection> sections;
  final String conclusion;

  const Summary({
    required this.title,
    required this.overview,
    required this.keyPoints,
    required this.sections,
    required this.conclusion,
  });

  factory Summary.fromJson(Map<String, dynamic> json) => Summary(
    title: json['title'] as String? ?? '',
    overview: json['overview'] as String? ?? '',
    keyPoints: (json['key_points'] as List? ?? []).cast<String>(),
    sections: (json['sections'] as List? ?? [])
        .map((e) => SummarySection.fromJson(e as Map<String, dynamic>))
        .toList(),
    conclusion: json['conclusion'] as String? ?? '',
  );
}

class SummarySection {
  final String heading;
  final String content;

  const SummarySection({required this.heading, required this.content});

  factory SummarySection.fromJson(Map<String, dynamic> json) => SummarySection(
    heading: json['heading'] as String? ?? '',
    content: json['content'] as String? ?? '',
  );
}

// ── QCM Question ──────────────────────────────────────────────────────────────
class QcmQuestion {
  final int id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QcmQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory QcmQuestion.fromJson(Map<String, dynamic> json) => QcmQuestion(
    id: json['id'] as int? ?? 0,
    question: json['question'] as String,
    options: (json['options'] as List).cast<String>(),
    correctIndex: json['correct_index'] as int? ?? 0,
    explanation: json['explanation'] as String? ?? '',
  );
}
