class Course {
  final int id;
  final String title;
  final String? description;
  final String? color;
  final String? icon;
  final String visibility; // 'public' | 'private'
  final bool isFavorite;
  final bool isMine;
  final bool isSaved;
  final String ownerName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Course({
    required this.id,
    required this.title,
    this.description,
    this.color,
    this.icon,
    required this.visibility,
    required this.isFavorite,
    required this.isMine,
    required this.isSaved,
    required this.ownerName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id:          json['id'] as int,
      title:       json['title'] as String,
      description: json['description'] as String?,
      color:       json['color'] as String?,
      icon:        json['icon'] as String?,
      visibility:  json['visibility'] as String? ?? 'private',
      isFavorite:  json['is_favorite'] == true,
      isMine:      json['is_mine'] == true,
      isSaved:     json['is_saved'] == true,
      ownerName:   json['owner_name'] as String? ?? '',
      createdAt:   DateTime.parse(json['created_at'] as String),
      updatedAt:   DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isPublic => visibility == 'public';

  Course copyWith({
    bool? isFavorite,
    bool? isSaved,
    String? title,
    String? description,
    String? visibility,
    String? color,
    String? icon,
  }) {
    return Course(
      id:          id,
      title:       title ?? this.title,
      description: description ?? this.description,
      color:       color ?? this.color,
      icon:        icon ?? this.icon,
      visibility:  visibility ?? this.visibility,
      isFavorite:  isFavorite ?? this.isFavorite,
      isMine:      isMine,
      isSaved:     isSaved ?? this.isSaved,
      ownerName:   ownerName,
      createdAt:   createdAt,
      updatedAt:   updatedAt,
    );
  }
}

enum CourseTab { all, mine, public, saved }

enum CourseSort { recent, favorite, alpha }
