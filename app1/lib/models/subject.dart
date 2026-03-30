class Subject {
  final int id;
  final String name;
  final int chaptersCount;
  final int documentsCount;
  final String? colorHex; // optional tint per subject

  const Subject({
    required this.id,
    required this.name,
    this.chaptersCount = 0,
    this.documentsCount = 0,
    this.colorHex,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as int,
      name: json['name'] as String,
      chaptersCount: json['chapters_count'] as int? ?? 0,
      documentsCount: json['documents_count'] as int? ?? 0,
      colorHex: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'chapters_count': chaptersCount,
    'documents_count': documentsCount,
    if (colorHex != null) 'color': colorHex,
  };

  Subject copyWith({String? name, String? colorHex}) => Subject(
    id: id,
    name: name ?? this.name,
    chaptersCount: chaptersCount,
    documentsCount: documentsCount,
    colorHex: colorHex ?? this.colorHex,
  );
}
