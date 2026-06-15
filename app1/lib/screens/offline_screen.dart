import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class SavedCourseLocal {
  final int id;
  final int courseId;
  final String title;
  final String ownerName;
  final bool isPublic;
  final DateTime savedAt;
  final List<SavedContentLocal> contents;

  const SavedCourseLocal({
    required this.id,
    required this.courseId,
    required this.title,
    required this.ownerName,
    required this.isPublic,
    required this.savedAt,
    required this.contents,
  });

  factory SavedCourseLocal.fromJson(Map<String, dynamic> json) {
    return SavedCourseLocal(
      id: json['id'] as int,
      courseId: json['course_id'] as int,
      title: json['title'] as String,
      ownerName: json['owner_name'] as String? ?? 'Unknown',
      isPublic: json['is_public'] as bool? ?? false,
      savedAt:
          DateTime.tryParse(json['saved_at'] as String? ?? '') ??
          DateTime.now(),
      contents: (json['contents'] as List<dynamic>? ?? [])
          .map((e) => SavedContentLocal.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'course_id': courseId,
    'title': title,
    'owner_name': ownerName,
    'is_public': isPublic,
    'saved_at': savedAt.toIso8601String(),
    'contents': contents.map((c) => c.toJson()).toList(),
  };
}

class SavedContentLocal {
  final int id;
  final String tool; // flashcards | summary | qcm
  final Map<String, dynamic> content;
  final DateTime savedAt;

  const SavedContentLocal({
    required this.id,
    required this.tool,
    required this.content,
    required this.savedAt,
  });

  factory SavedContentLocal.fromJson(Map<String, dynamic> json) {
    return SavedContentLocal(
      id: json['id'] as int,
      tool: json['tool'] as String,
      content: json['content'] as Map<String, dynamic>? ?? {},
      savedAt:
          DateTime.tryParse(json['saved_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tool': tool,
    'content': content,
    'saved_at': savedAt.toIso8601String(),
  };

  IconData get icon => switch (tool) {
    'flashcards' => Icons.style_rounded,
    'summary' => Icons.auto_awesome_rounded,
    'qcm' => Icons.quiz_rounded,
    _ => Icons.description_outlined,
  };

  String get label => switch (tool) {
    'flashcards' => 'Flashcards',
    'summary' => 'Summary',
    'qcm' => 'Quiz',
    _ => tool,
  };

  Color get color => switch (tool) {
    'flashcards' => const Color(0xFF7C3AED),
    'summary' => const Color(0xFF0EA5E9),
    'qcm' => const Color(0xFF10B981),
    _ => const Color(0xFF3055E7),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Local Storage Helper
// ─────────────────────────────────────────────────────────────────────────────

const _kSavedCoursesKey = 'smartstudy_saved_courses';

class LocalStorage {
  static Future<List<SavedCourseLocal>> loadSavedCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSavedCoursesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedCourseLocal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCourse(SavedCourseLocal course) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSavedCourses();
    final updated = [
      ...existing.where((c) => c.courseId != course.courseId),
      course,
    ];
    await prefs.setString(
      _kSavedCoursesKey,
      jsonEncode(updated.map((c) => c.toJson()).toList()),
    );
  }

  static Future<void> removeCourse(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSavedCourses();
    final updated = existing.where((c) => c.courseId != courseId).toList();
    await prefs.setString(
      _kSavedCoursesKey,
      jsonEncode(updated.map((c) => c.toJson()).toList()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final offlineCoursesProvider =
    AsyncNotifierProvider<OfflineCoursesNotifier, List<SavedCourseLocal>>(
      OfflineCoursesNotifier.new,
    );

class OfflineCoursesNotifier extends AsyncNotifier<List<SavedCourseLocal>> {
  @override
  Future<List<SavedCourseLocal>> build() => LocalStorage.loadSavedCourses();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await LocalStorage.loadSavedCourses());
  }

  Future<void> remove(int courseId) async {
    await LocalStorage.removeCourse(courseId);
    await refresh();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accent colours — same palette as home_screen
// ─────────────────────────────────────────────────────────────────────────────

const _kAccents = [
  Color(0xFF3055E7),
  Color(0xFF7C3AED),
  Color(0xFF0EA5E9),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
];
Color _accentFor(int id) => _kAccents[id % _kAccents.length];

// ─────────────────────────────────────────────────────────────────────────────
// Offline Screen — entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Drop-in replacement when the user is offline / unauthenticated.
/// Shows saved courses from local device storage. No internet required.
class OfflineScreen extends ConsumerWidget {
  const OfflineScreen({super.key});

  // Colour constants — kept inline so this file is self-contained.
  // Swap for AppColors.of(context) once you wire up the theme.
  static const _bg = Color(0xFF0F1117);
  static const _surface = Color(0xFF181C27);
  static const _card = Color(0xFF1E2333);
  static const _cardBorder = Color(0xFF2A2F45);
  static const _primary = Color(0xFF3055E7);
  static const _primarySoft = Color(0xFF3055E7);
  static const _text = Color(0xFFEBEDF5);
  static const _textSub = Color(0xFF8890A8);
  static const _fieldBg = Color(0xFF1E2333);
  static const _divider = Color(0xFF252A3D);
  static const _shimmer = Color(0xFF252A3D);
  static const _warn = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _OfflineHeader(),
            _OfflineBanner(),
            const Gap(8),
            const Expanded(child: _OfflineCourseList()),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          // Logo placeholder — replace with Image.asset('images/logo.png')
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: OfflineScreen._primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: OfflineScreen._primary.withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: OfflineScreen._primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'SmartStudy',
            style: TextStyle(
              color: OfflineScreen._primary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          // Offline badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: OfflineScreen._warn.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: OfflineScreen._warn.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: OfflineScreen._warn,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Offline',
                  style: TextStyle(
                    color: OfflineScreen._warn,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offline Banner
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OfflineScreen._warn.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OfflineScreen._warn.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: OfflineScreen._warn.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: OfflineScreen._warn,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You\'re offline',
                  style: TextStyle(
                    color: OfflineScreen._warn,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Showing your downloaded courses. Log in to access all features.',
                  style: TextStyle(
                    color: OfflineScreen._warn.withOpacity(0.75),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Course List
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineCourseList extends ConsumerWidget {
  const _OfflineCourseList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(offlineCoursesProvider);

    return coursesAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        itemCount: 5,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: _ShimmerBox(height: 82),
        ),
      ),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: OfflineScreen._textSub,
              size: 40,
            ),
            const Gap(12),
            const Text(
              'Could not read offline data',
              style: TextStyle(color: OfflineScreen._textSub, fontSize: 14),
            ),
            const Gap(12),
            _PrimaryButton(
              label: 'Retry',
              onTap: () => ref.refresh(offlineCoursesProvider),
            ),
          ],
        ),
      ),
      data: (courses) {
        if (courses.isEmpty) return const _EmptyOfflineState();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Text(
                    'Downloaded Courses',
                    style: TextStyle(
                      color: OfflineScreen._text,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: OfflineScreen._primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${courses.length}',
                      style: TextStyle(
                        color: OfflineScreen._primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: OfflineScreen._primary,
                onRefresh: () =>
                    ref.read(offlineCoursesProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: courses.length,
                  itemBuilder: (_, i) => _OfflineCourseItem(
                    course: courses[i],
                    onDelete: () => ref
                        .read(offlineCoursesProvider.notifier)
                        .remove(courses[i].courseId),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Course Item Card
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineCourseItem extends StatelessWidget {
  final SavedCourseLocal course;
  final VoidCallback onDelete;

  const _OfflineCourseItem({required this.course, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(course.courseId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: OfflineScreen._card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OfflineScreen._cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetail(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row ──
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withOpacity(0.25)),
                      ),
                      child: Center(
                        child: Text(
                          course.title.isNotEmpty
                              ? course.title[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.title,
                            style: const TextStyle(
                              color: OfflineScreen._text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 11,
                                color: OfflineScreen._textSub,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  course.ownerName,
                                  style: const TextStyle(
                                    color: OfflineScreen._textSub,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Offline badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: OfflineScreen._primary.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Downloaded',
                                  style: TextStyle(
                                    color: OfflineScreen._primary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 3-dot menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: OfflineScreen._textSub,
                        size: 20,
                      ),
                      color: OfflineScreen._surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: OfflineScreen._cardBorder),
                      ),
                      elevation: 2,
                      onSelected: (v) {
                        if (v == 'remove') _confirmRemove(context);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Colors.redAccent.shade200,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Remove offline',
                                style: TextStyle(
                                  color: Colors.redAccent.shade200,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ── Content chips ──
                if (course.contents.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: OfflineScreen._cardBorder),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: course.contents
                        .map((c) => _ContentChip(content: c))
                        .toList(),
                  ),
                ],

                // ── Saved date ──
                const SizedBox(height: 8),
                Text(
                  'Saved ${_formatDate(course.savedAt)}',
                  style: const TextStyle(
                    color: OfflineScreen._textSub,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _OfflineCourseDetail(course: course)),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (d) => AlertDialog(
        backgroundColor: OfflineScreen._surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: OfflineScreen._cardBorder),
        ),
        title: const Text(
          'Remove offline copy',
          style: TextStyle(
            color: OfflineScreen._text,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Remove "${course.title}" from your device? You\'ll need internet to access it again.',
          style: const TextStyle(color: OfflineScreen._textSub, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text(
              'Cancel',
              style: TextStyle(color: OfflineScreen._textSub),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(d);
              onDelete();
            },
            child: const Text(
              'Remove',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content Chip (flashcards / summary / quiz)
// ─────────────────────────────────────────────────────────────────────────────

class _ContentChip extends StatelessWidget {
  final SavedContentLocal content;
  const _ContentChip({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: content.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: content.color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(content.icon, size: 12, color: content.color),
          const SizedBox(width: 4),
          Text(
            content.label,
            style: TextStyle(
              color: content.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offline Course Detail Screen
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineCourseDetail extends StatefulWidget {
  final SavedCourseLocal course;
  const _OfflineCourseDetail({required this.course});

  @override
  State<_OfflineCourseDetail> createState() => _OfflineCourseDetailState();
}

class _OfflineCourseDetailState extends State<_OfflineCourseDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: widget.course.contents.isEmpty
          ? 1
          : widget.course.contents.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(widget.course.courseId);
    final contents = widget.course.contents;

    return Scaffold(
      backgroundColor: OfflineScreen._bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: OfflineScreen._text,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.course.title,
                          style: const TextStyle(
                            color: OfflineScreen._text,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 11,
                              color: OfflineScreen._textSub,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.course.ownerName,
                              style: const TextStyle(
                                color: OfflineScreen._textSub,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: OfflineScreen._warn.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: OfflineScreen._warn.withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          color: OfflineScreen._warn,
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Offline',
                          style: TextStyle(
                            color: OfflineScreen._warn,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Gap(12),

            if (contents.isEmpty)
              const Expanded(child: _NoContentState())
            else ...[
              // Tab bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: OfflineScreen._fieldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: OfflineScreen._cardBorder),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: OfflineScreen._textSub,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: contents.map((c) => Tab(text: c.label)).toList(),
                  ),
                ),
              ),

              const Gap(12),

              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: contents
                      .map((c) => _ContentViewer(content: c))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Content Viewer — renders flashcards / summary / quiz from local JSON
// ─────────────────────────────────────────────────────────────────────────────

class _ContentViewer extends StatelessWidget {
  final SavedContentLocal content;
  const _ContentViewer({required this.content});

  @override
  Widget build(BuildContext context) {
    return switch (content.tool) {
      'flashcards' => _FlashcardViewer(content: content),
      'summary' => _SummaryViewer(content: content),
      'qcm' => _QuizViewer(content: content),
      _ => _RawJsonViewer(content: content),
    };
  }
}

// ── Flashcards ────────────────────────────────────────────────────────────────

class _FlashcardViewer extends StatefulWidget {
  final SavedContentLocal content;
  const _FlashcardViewer({required this.content});
  @override
  State<_FlashcardViewer> createState() => _FlashcardViewerState();
}

class _FlashcardViewerState extends State<_FlashcardViewer> {
  int _index = 0;
  bool _flipped = false;

  List<dynamic> get _cards =>
      widget.content.content['cards'] as List<dynamic>? ?? [];

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return const Center(
        child: Text(
          'No cards available.',
          style: TextStyle(color: OfflineScreen._textSub),
        ),
      );
    }

    final card = _cards[_index] as Map<String, dynamic>;
    final question = card['question'] as String? ?? '';
    final answer = card['answer'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            '${_index + 1} / ${_cards.length}',
            style: const TextStyle(color: OfflineScreen._textSub, fontSize: 12),
          ),
          const Gap(12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _flipped = !_flipped),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey('$_index-$_flipped'),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: OfflineScreen._card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: OfflineScreen._cardBorder),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _flipped ? 'Answer' : 'Question',
                        style: TextStyle(
                          color: _flipped
                              ? const Color(0xFF10B981)
                              : OfflineScreen._primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(16),
                      Text(
                        _flipped ? answer : question,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: OfflineScreen._text,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      const Gap(16),
                      Text(
                        'Tap to flip',
                        style: TextStyle(
                          color: OfflineScreen._textSub.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Gap(16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavBtn(
                icon: Icons.arrow_back_rounded,
                enabled: _index > 0,
                onTap: () => setState(() {
                  _index--;
                  _flipped = false;
                }),
              ),
              _NavBtn(
                icon: Icons.arrow_forward_rounded,
                enabled: _index < _cards.length - 1,
                onTap: () => setState(() {
                  _index++;
                  _flipped = false;
                }),
              ),
            ],
          ),
          const Gap(20),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _NavBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled
              ? OfflineScreen._primary.withOpacity(0.15)
              : OfflineScreen._fieldBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? OfflineScreen._primary.withOpacity(0.3)
                : OfflineScreen._cardBorder,
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? OfflineScreen._primary : OfflineScreen._textSub,
          size: 20,
        ),
      ),
    );
  }
}

// ── Summary ───────────────────────────────────────────────────────────────────

class _SummaryViewer extends StatelessWidget {
  final SavedContentLocal content;
  const _SummaryViewer({required this.content});

  @override
  Widget build(BuildContext context) {
    final overview = content.content['overview'] as String? ?? '';
    final keyPoints = content.content['key_points'] as List<dynamic>? ?? [];
    final sections = content.content['sections'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (overview.isNotEmpty) ...[
          _SectionTitle('Overview'),
          const Gap(8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OfflineScreen._card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OfflineScreen._cardBorder),
            ),
            child: Text(
              overview,
              style: const TextStyle(
                color: OfflineScreen._text,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
          const Gap(16),
        ],
        if (keyPoints.isNotEmpty) ...[
          _SectionTitle('Key Points'),
          const Gap(8),
          ...keyPoints.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 10, top: 1),
                    decoration: BoxDecoration(
                      color: OfflineScreen._primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                          color: OfflineScreen._primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value.toString(),
                      style: const TextStyle(
                        color: OfflineScreen._text,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(8),
        ],
        if (sections.isNotEmpty) ...[
          _SectionTitle('Sections'),
          const Gap(8),
          ...sections.map((s) {
            final sec = s as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OfflineScreen._card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: OfflineScreen._cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sec['title'] as String? ?? '',
                    style: const TextStyle(
                      color: OfflineScreen._text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Gap(6),
                  Text(
                    sec['content'] as String? ?? '',
                    style: const TextStyle(
                      color: OfflineScreen._textSub,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ── Quiz ──────────────────────────────────────────────────────────────────────

class _QuizViewer extends StatefulWidget {
  final SavedContentLocal content;
  const _QuizViewer({required this.content});
  @override
  State<_QuizViewer> createState() => _QuizViewerState();
}

class _QuizViewerState extends State<_QuizViewer> {
  int _index = 0;
  int? _selected;
  int _score = 0;
  bool _finished = false;

  List<dynamic> get _questions =>
      widget.content.content['questions'] as List<dynamic>? ?? [];

  void _pick(int i, int correct) {
    if (_selected != null) return;
    setState(() {
      _selected = i;
      if (i == correct) _score++;
    });
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
      });
    } else {
      setState(() => _finished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Center(
        child: Text(
          'No questions available.',
          style: TextStyle(color: OfflineScreen._textSub),
        ),
      );
    }

    if (_finished) {
      return _QuizScore(
        score: _score,
        total: _questions.length,
        onRetry: () => setState(() {
          _index = 0;
          _selected = null;
          _score = 0;
          _finished = false;
        }),
      );
    }

    final q = _questions[_index] as Map<String, dynamic>;
    final question = q['question'] as String? ?? '';
    final options = (q['options'] as List<dynamic>?)?.cast<String>() ?? [];
    final correct = q['correct_index'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Q${_index + 1}/${_questions.length}',
                style: const TextStyle(
                  color: OfflineScreen._textSub,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '$_score pts',
                style: const TextStyle(
                  color: OfflineScreen._primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Gap(12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OfflineScreen._card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OfflineScreen._cardBorder),
            ),
            child: Text(
              question,
              style: const TextStyle(
                color: OfflineScreen._text,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
          const Gap(12),
          ...options.asMap().entries.map((e) {
            final idx = e.key;
            final opt = e.value;
            Color? bg, border, textCol;

            if (_selected != null) {
              if (idx == correct) {
                bg = const Color(0xFF10B981).withOpacity(0.15);
                border = const Color(0xFF10B981).withOpacity(0.5);
                textCol = const Color(0xFF10B981);
              } else if (idx == _selected) {
                bg = Colors.redAccent.withOpacity(0.12);
                border = Colors.redAccent.withOpacity(0.4);
                textCol = Colors.redAccent;
              } else {
                bg = OfflineScreen._fieldBg;
                border = OfflineScreen._cardBorder;
                textCol = OfflineScreen._textSub;
              }
            } else {
              bg = OfflineScreen._fieldBg;
              border = OfflineScreen._cardBorder;
              textCol = OfflineScreen._text;
            }

            return GestureDetector(
              onTap: () => _pick(idx, correct),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border!),
                ),
                child: Row(
                  children: [
                    Text(
                      '${String.fromCharCode(65 + idx)}.',
                      style: TextStyle(
                        color: textCol,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        opt,
                        style: TextStyle(
                          color: textCol,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          if (_selected != null)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OfflineScreen._primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _next,
                child: Text(
                  _index < _questions.length - 1 ? 'Next' : 'Finish',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuizScore extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onRetry;
  const _QuizScore({
    required this.score,
    required this.total,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (score / total * 100).round();
    final color = pct >= 70
        ? const Color(0xFF10B981)
        : pct >= 40
        ? OfflineScreen._warn
        : Colors.redAccent;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.4), width: 2),
              ),
              child: Center(
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const Gap(16),
            Text(
              '$score / $total correct',
              style: const TextStyle(
                color: OfflineScreen._text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(8),
            Text(
              pct >= 70
                  ? 'Great job! Keep it up 🎉'
                  : pct >= 40
                  ? 'Good effort, keep studying!'
                  : 'Review the material and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: OfflineScreen._textSub,
                fontSize: 13,
              ),
            ),
            const Gap(24),
            _PrimaryButton(label: 'Retry Quiz', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _RawJsonViewer extends StatelessWidget {
  final SavedContentLocal content;
  const _RawJsonViewer({required this.content});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        const JsonEncoder.withIndent('  ').convert(content.content),
        style: const TextStyle(color: OfflineScreen._textSub, fontSize: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: OfflineScreen._text,
      fontWeight: FontWeight.w700,
      fontSize: 14,
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: OfflineScreen._primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  const _ShimmerBox({required this.height});
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: OfflineScreen._shimmer,
      borderRadius: BorderRadius.circular(14),
    ),
  );
}

class _EmptyOfflineState extends StatelessWidget {
  const _EmptyOfflineState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: OfflineScreen._primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_outlined,
                color: OfflineScreen._primary,
                size: 36,
              ),
            ),
            const Gap(16),
            const Text(
              'No offline courses',
              style: TextStyle(
                color: OfflineScreen._text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(8),
            const Text(
              'When online, save courses for offline access.\nThey\'ll appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: OfflineScreen._textSub, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoContentState extends StatelessWidget {
  const _NoContentState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No content saved for this course.',
        style: TextStyle(color: OfflineScreen._textSub, fontSize: 14),
      ),
    );
  }
}
