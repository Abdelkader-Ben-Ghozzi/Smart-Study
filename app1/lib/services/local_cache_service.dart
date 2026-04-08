import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/course.dart';
import '../models/course_details_models.dart';

/// Local offline cache using Hive.
/// Stores courses, sources, and generated content per course.
///
/// Setup in main.dart:
///   await Hive.initFlutter();
///   await LocalCacheService.init();
class LocalCacheService {
  static const _courseBox = 'cached_courses';
  static const _sourceBox = 'cached_sources';
  static const _contentBox = 'cached_ai_content';

  static Future<void> init() async {
    await Hive.openBox(_courseBox);
    await Hive.openBox(_sourceBox);
    await Hive.openBox(_contentBox);
  }

  // ── Courses ───────────────────────────────────────────────────────────────

  static Future<void> saveCourses(List<Course> courses) async {
    final box = Hive.box(_courseBox);
    final data = courses
        .map(
          (c) => jsonEncode({
            'id': c.id,
            'title': c.title,
            'description': c.description,
            'color': c.color,
            'icon': c.icon,
            'visibility': c.visibility,
            'is_mine': c.isMine,
            'is_favorite': c.isFavorite,
            'is_saved': c.isSaved,
            'owner_name': c.ownerName,
            'sources_count': 0,
            'created_at': c.createdAt.toIso8601String(),
            'updated_at': c.updatedAt.toIso8601String(),
          }),
        )
        .toList();
    await box.put('all', data);
  }

  static List<Course> loadCourses() {
    final box = Hive.box(_courseBox);
    final data = box.get('all');
    if (data == null) return [];
    return (data as List)
        .map(
          (e) =>
              Course.fromJson(jsonDecode(e as String) as Map<String, dynamic>),
        )
        .toList();
  }

  // ── Sources per course ─────────────────────────────────────────────────────

  static Future<void> saveSources(
    int courseId,
    List<CourseSource> sources,
  ) async {
    final box = Hive.box(_sourceBox);
    final data = sources
        .map(
          (s) => jsonEncode({
            'id': s.id,
            'course_id': s.courseId,
            'name': s.name,
            'type': s.type,
            'mime_type': s.mimeType,
            'size': s.size,
            'url': s.url,
            'created_at': s.createdAt.toIso8601String(),
          }),
        )
        .toList();
    await box.put('course_$courseId', data);
  }

  static List<CourseSource> loadSources(int courseId) {
    final box = Hive.box(_sourceBox);
    final data = box.get('course_$courseId');
    if (data == null) return [];
    return (data as List)
        .map(
          (e) => CourseSource.fromJson(
            jsonDecode(e as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  // ── Generated content per course ───────────────────────────────────────────

  static Future<void> saveGeneratedContent(
    int courseId,
    List<GeneratedContent> items,
  ) async {
    final box = Hive.box(_contentBox);
    final data = items
        .map(
          (g) => jsonEncode({
            'id': g.id,
            'course_id': g.courseId,
            'tool': g.tool.name,
            'title': g.title,
            'content': g.content,
            'options': g.options,
            'created_at': g.createdAt.toIso8601String(),
          }),
        )
        .toList();
    await box.put('course_$courseId', data);
  }

  static List<GeneratedContent> loadGeneratedContent(int courseId) {
    final box = Hive.box(_contentBox);
    final data = box.get('course_$courseId');
    if (data == null) return [];
    return (data as List)
        .map(
          (e) => GeneratedContent.fromJson(
            jsonDecode(e as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  // ── Append a single generated item after AI returns ───────────────────────

  static Future<void> appendGeneratedContent(
    int courseId,
    GeneratedContent item,
  ) async {
    final existing = loadGeneratedContent(courseId);
    existing.insert(0, item); // newest first
    await saveGeneratedContent(courseId, existing);
  }

  // ── Clear all cache ───────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    await Hive.box(_courseBox).clear();
    await Hive.box(_sourceBox).clear();
    await Hive.box(_contentBox).clear();
  }
}
