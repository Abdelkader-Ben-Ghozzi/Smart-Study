import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'course_details.dart';
import '../models/course.dart';
import '../models/user_model.dart';
import '../providers/courses_provider.dart';
import '../providers/home_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer_box.dart';
import 'profile_screen.dart';
import 'stats_screen.dart';

// ── Accent palette ────────────────────────────────────────────────────────────
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

// ── Root ──────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final scheme = isDark ? AppColorScheme.dark : AppColorScheme.light;

    return AppColors(
      scheme: scheme,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: const _HomeScaffold(),
      ),
    );
  }
}

// ── Scaffold ──────────────────────────────────────────────────────────────────
class _HomeScaffold extends ConsumerStatefulWidget {
  const _HomeScaffold();
  @override
  ConsumerState<_HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends ConsumerState<_HomeScaffold> {
  int _navIndex = 0;

  // ── Use IndexedStack so pages keep their state ────────────────────────────
  final _pages = const [
    _CoursesPage(),
    _PlaceholderTab(index: 1),
    _PlaceholderTab(index: 2),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      // IndexedStack keeps all pages in memory — no rebuild on tab switch
      body: IndexedStack(index: _navIndex, children: _pages),
      bottomNavigationBar: _BottomNav(
        current: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

// ── Courses page ──────────────────────────────────────────────────────────────
class _CoursesPage extends ConsumerStatefulWidget {
  const _CoursesPage();
  @override
  ConsumerState<_CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<_CoursesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  bool _searchOpen = false;

  final _tabs = const [
    (CourseTab.all, 'All'),
    (CourseTab.mine, 'My Courses'),
    (CourseTab.saved, 'Saved'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        ref.read(courseTabProvider.notifier).state = _tabs[_tabCtrl.index].$1;
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCreateDialog() async {
    final c = AppColors.of(context);
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateCourseSheet(colors: c),
    );
    if (result != null && mounted) {
      final res = await ref
          .read(coursesProvider.notifier)
          .create(
            title: result['title']!,
            description: result['description'],
            visibility: result['visibility'] ?? 'private',
          );
      if (res['success'] != true && mounted) {
        final c = AppColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to create course'),
            backgroundColor: c.borderError,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final userAsync = ref.watch(userProvider);
    final sort = ref.watch(courseSortProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _AppHeader(userAsync: userAsync),

            // ── Controls ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _searchOpen
                    ? _SearchBar(
                        key: const ValueKey('search'),
                        controller: _searchCtrl,
                        colors: c,
                        onClose: () {
                          setState(() => _searchOpen = false);
                          _searchCtrl.clear();
                          ref.read(courseSearchProvider.notifier).state = '';
                        },
                        onChanged: (v) =>
                            ref.read(courseSearchProvider.notifier).state = v,
                      )
                    : _ControlBar(
                        key: const ValueKey('controls'),
                        sort: sort,
                        colors: c,
                        onSortChanged: (s) =>
                            ref.read(courseSortProvider.notifier).state = s,
                        onSearchTap: () => setState(() => _searchOpen = true),
                        onCreateTap: _openCreateDialog,
                      ),
              ),
            ),

            const Gap(12),

            // ── Tabs ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: c.fieldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.borderDefault),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: c.subtitle,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: _tabs.map((t) => Tab(text: t.$2)).toList(),
                ),
              ),
            ),

            const Gap(12),

            // ── List ──
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: _tabs.map((_) => _CourseList(colors: c)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App Header ────────────────────────────────────────────────────────────────
class _AppHeader extends ConsumerWidget {
  final AsyncValue userAsync;
  const _AppHeader({required this.userAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
      child: Row(
        children: [
          // Logo
          Image.asset(
            'images/logo.png',
            width: 100,
            height: 50,
            errorBuilder: (_, __, ___) => Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'SmartStudy',
            style: TextStyle(
              color: c.primary,
              fontWeight: FontWeight.w800,
              fontSize: 25,
              letterSpacing: -0.3,
            ),
          ),

          const Spacer(),

          // Theme toggle
          GestureDetector(
            onTap: () => ref.read(themeModeProvider.notifier).state = isDark
                ? ThemeMode.light
                : ThemeMode.dark,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: c.fieldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.borderDefault),
              ),
              child: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: c.textSecondary,
                size: 18,
              ),
            ),
          ),

          // ── Avatar — shows real photo if set, initials otherwise ──────────────
          userAsync.when(
            data: (u) => _HomeAvatar(user: u, colors: c),
            loading: () => _HomeAvatarShimmer(colors: c),
            error: (_, __) => _HomeAvatarShimmer(colors: c),
          ),
        ],
      ),
    );
  }
}

// ── Home avatar widget — photo > initials ─────────────────────────────────────
class _HomeAvatar extends StatelessWidget {
  final UserModel user;
  final AppColorScheme colors;
  static const double _size = 44;

  const _HomeAvatar({required this.user, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final url = user.avatarUrl(); // null when no photo uploaded

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Gradient shows through only when no photo (initials fallback)
        gradient: url == null
            ? LinearGradient(
                colors: [c.primary, c.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: c.primary.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: url != null
            ? Image.network(
                url,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                // Falls back to gradient + initials if image fails / offline
                errorBuilder: (_, __, ___) => _Initials(user: user, colors: c),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _HomeAvatarShimmer(colors: c),
              )
            : _Initials(user: user, colors: c),
      ),
    );
  }
}

// ── Initials fallback ─────────────────────────────────────────────────────────
class _Initials extends StatelessWidget {
  final UserModel user;
  final AppColorScheme colors;
  const _Initials({required this.user, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.primary, c.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

// ── Shimmer placeholder while user loads ──────────────────────────────────────
class _HomeAvatarShimmer extends StatelessWidget {
  final AppColorScheme colors;
  const _HomeAvatarShimmer({required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.shimmerBase,
        border: Border.all(color: c.borderDefault),
      ),
      child: Icon(Icons.person_outline, color: c.iconDefault, size: 22),
    );
  }
}

// ── Control bar ───────────────────────────────────────────────────────────────
class _ControlBar extends StatelessWidget {
  final CourseSort sort;
  final AppColorScheme colors;
  final ValueChanged<CourseSort> onSortChanged;
  final VoidCallback onSearchTap;
  final VoidCallback onCreateTap;

  const _ControlBar({
    super.key,
    required this.sort,
    required this.colors,
    required this.onSortChanged,
    required this.onSearchTap,
    required this.onCreateTap,
  });

  String get _sortLabel => switch (sort) {
    CourseSort.recent => 'Most Recent',
    CourseSort.favorite => 'Favorites',
    CourseSort.alpha => 'A → Z',
  };

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showSortSheet(context),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.fieldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.borderDefault),
              ),
              child: Row(
                children: [
                  Icon(Icons.sort_rounded, color: c.iconDefault, size: 17),
                  const SizedBox(width: 6),
                  Text(
                    _sortLabel,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: c.iconDefault,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _IconBtn(icon: Icons.search_rounded, colors: c, onTap: onSearchTap),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onCreateTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, color: Colors.white, size: 17),
                const SizedBox(width: 4),
                const Text(
                  'Create',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSortSheet(BuildContext context) {
    final c = colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Sort by',
                style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 14),
              ...CourseSort.values.map((s) {
                final label = switch (s) {
                  CourseSort.recent => 'Most Recent',
                  CourseSort.favorite => 'Favorites first',
                  CourseSort.alpha => 'Alphabetical (A → Z)',
                };
                final icon = switch (s) {
                  CourseSort.recent => Icons.access_time_rounded,
                  CourseSort.favorite => Icons.star_rounded,
                  CourseSort.alpha => Icons.sort_by_alpha_rounded,
                };
                final isActive = sort == s;
                return GestureDetector(
                  onTap: () {
                    onSortChanged(s);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? c.primary.withOpacity(0.1) : c.fieldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? c.primary.withOpacity(0.4)
                            : c.borderDefault,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          color: isActive ? c.primary : c.iconDefault,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: TextStyle(
                            color: isActive ? c.primary : c.text,
                            fontSize: 14,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        if (isActive) ...[
                          const Spacer(),
                          Icon(Icons.check_rounded, color: c.primary, size: 18),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────
class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final AppColorScheme colors;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    super.key,
    required this.controller,
    required this.colors,
    required this.onClose,
    required this.onChanged,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final FocusNode _fn;

  @override
  void initState() {
    super.initState();
    _fn = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fn.requestFocus());
  }

  @override
  void dispose() {
    _fn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: c.fieldBgFocus,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.borderFocus, width: 1.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(Icons.search_rounded, color: c.iconFocus, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _fn,
              onChanged: widget.onChanged,
              style: TextStyle(color: c.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by title…',
                hintStyle: TextStyle(color: c.hint, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: c.iconDefault, size: 18),
            padding: EdgeInsets.zero,
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
}

// ── Course list ───────────────────────────────────────────────────────────────
class _CourseList extends ConsumerWidget {
  final AppColorScheme colors;
  const _CourseList({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = colors;
    final coursesAsync = ref.watch(coursesProvider);

    return coursesAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ShimmerBox(width: double.infinity, height: 72, radius: 14),
        ),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: c.iconDefault, size: 40),
            const Gap(12),
            Text(
              'Failed to load courses',
              style: TextStyle(color: c.textSecondary, fontSize: 14),
            ),
            const Gap(12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => ref.refresh(coursesProvider),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      data: (courses) => courses.isEmpty
          ? _EmptyState(colors: c)
          : RefreshIndicator(
              color: c.primary,
              onRefresh: () async => ref.refresh(coursesProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: courses.length,
                itemBuilder: (_, i) => _CourseItem(
                  course: courses[i],
                  colors: c,
                  onFavorite: () => ref
                      .read(coursesProvider.notifier)
                      .toggleFavorite(courses[i].id),
                  onSave: () => ref
                      .read(coursesProvider.notifier)
                      .toggleSave(courses[i].id),
                  onRename: (title, vis) => ref
                      .read(coursesProvider.notifier)
                      .rename(courses[i].id, title, visibility: vis),
                  onDelete: () =>
                      ref.read(coursesProvider.notifier).delete(courses[i].id),
                ),
              ),
            ),
    );
  }
}

// ── Course item ───────────────────────────────────────────────────────────────
class _CourseItem extends StatelessWidget {
  final Course course;
  final AppColorScheme colors;
  final VoidCallback onFavorite;
  final VoidCallback onSave;
  final Future<Map<String, dynamic>> Function(String, String?) onRename;
  final Future<Map<String, dynamic>> Function() onDelete;

  const _CourseItem({
    required this.course,
    required this.colors,
    required this.onFavorite,
    required this.onSave,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final accent = _accentFor(course.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(course: course),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Course initial avatar
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
                        style: TextStyle(
                          color: c.text,
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
                            course.isMine
                                ? Icons.person_outline
                                : Icons.public_outlined,
                            size: 11,
                            color: c.subtitle,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              course.isMine ? 'You' : course.ownerName,
                              style: TextStyle(color: c.subtitle, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: course.isPublic
                                  ? const Color(0xFF10B981).withOpacity(0.1)
                                  : c.fieldBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: course.isPublic
                                    ? const Color(0xFF10B981).withOpacity(0.3)
                                    : c.borderDefault,
                              ),
                            ),
                            child: Text(
                              course.isPublic ? 'Public' : 'Private',
                              style: TextStyle(
                                color: course.isPublic
                                    ? const Color(0xFF10B981)
                                    : c.subtitle,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (course.isSaved && !course.isMine) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: c.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Saved',
                                style: TextStyle(
                                  color: c.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (course.isMine)
                  GestureDetector(
                    onTap: onFavorite,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          course.isFavorite
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          key: ValueKey(course.isFavorite),
                          color: course.isFavorite
                              ? const Color(0xFFF59E0B)
                              : c.iconDefault,
                          size: 22,
                        ),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: onSave,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          course.isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_outline_rounded,
                          key: ValueKey(course.isSaved),
                          color: course.isSaved ? c.primary : c.iconDefault,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 2),
                _CourseMenu(
                  course: course,
                  colors: c,
                  onRename: onRename,
                  onDelete: onDelete,
                  onSave: course.isMine ? null : onSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 3-dot menu ────────────────────────────────────────────────────────────────
class _CourseMenu extends StatelessWidget {
  final Course course;
  final AppColorScheme colors;
  final Future<Map<String, dynamic>> Function(String, String?) onRename;
  final Future<Map<String, dynamic>> Function() onDelete;
  final VoidCallback? onSave;

  const _CourseMenu({
    required this.course,
    required this.colors,
    required this.onRename,
    required this.onDelete,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: c.iconDefault, size: 20),
      color: c.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borderDefault),
      ),
      elevation: 2,
      onSelected: (v) async {
        switch (v) {
          case 'rename':
            final result = await _showEditSheet(context, c);
            if (result != null) {
              await onRename(result['title']!, result['visibility']);
            }
          case 'delete':
            final confirmed = await _confirmDelete(context, c);
            if (confirmed == true) await onDelete();
          case 'save':
            onSave?.call();
        }
      },
      itemBuilder: (_) => [
        if (course.isMine) ...[
          _item('rename', Icons.edit_outlined, 'Rename', c),
          _item('delete', Icons.delete_outline, 'Delete', c, danger: true),
        ] else ...[
          _item(
            'save',
            course.isSaved
                ? Icons.bookmark_remove_outlined
                : Icons.bookmark_add_outlined,
            course.isSaved ? 'Unsave' : 'Save',
            c,
          ),
        ],
      ],
    );
  }

  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String label,
    AppColorScheme c, {
    bool danger = false,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: danger ? c.borderError : c.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: danger ? c.borderError : c.text,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _showEditSheet(
    BuildContext ctx,
    AppColorScheme c,
  ) => showModalBottomSheet<Map<String, String>>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditCourseSheet(course: course, colors: c),
  );

  Future<bool?> _confirmDelete(BuildContext ctx, AppColorScheme c) =>
      showDialog<bool>(
        context: ctx,
        barrierColor: Colors.black.withOpacity(0.6),
        builder: (d) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: c.borderDefault),
          ),
          title: Text(
            'Delete Course',
            style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Delete "${course.title}"? This cannot be undone.',
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.borderError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(d, true),
              child: const Text(
                'Delete',
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

// ── Create course sheet ───────────────────────────────────────────────────────
class _CreateCourseSheet extends StatefulWidget {
  final AppColorScheme colors;
  const _CreateCourseSheet({required this.colors});
  @override
  State<_CreateCourseSheet> createState() => _CreateCourseSheetState();
}

class _CreateCourseSheetState extends State<_CreateCourseSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _visibility = 'private';
  AppColorScheme get c => widget.colors;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.borderDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'New Course',
              style: TextStyle(
                color: c.text,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            _field(
              _titleCtrl,
              'Course title',
              Icons.book_outlined,
              c,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            _field(_descCtrl, 'Description (optional)', null, c, maxLines: 3),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Visibility',
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                _VisToggle(
                  value: _visibility,
                  colors: c,
                  onChange: (v) => setState(() => _visibility = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  final title = _titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  Navigator.pop(context, {
                    'title': title,
                    'description': _descCtrl.text.trim(),
                    'visibility': _visibility,
                  });
                },
                child: const Text(
                  'Create Course',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData? icon,
    AppColorScheme c, {
    bool autofocus = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      maxLines: maxLines,
      style: TextStyle(color: c.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.hint),
        filled: true,
        fillColor: c.fieldBg,
        prefixIcon: icon != null
            ? Icon(icon, color: c.iconDefault, size: 20)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.borderFocus, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

// ── Edit course sheet ─────────────────────────────────────────────────────────
class _EditCourseSheet extends StatefulWidget {
  final Course course;
  final AppColorScheme colors;
  const _EditCourseSheet({required this.course, required this.colors});
  @override
  State<_EditCourseSheet> createState() => _EditCourseSheetState();
}

class _EditCourseSheetState extends State<_EditCourseSheet> {
  late final TextEditingController _titleCtrl;
  late String _visibility;
  AppColorScheme get c => widget.colors;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.course.title);
    _visibility = widget.course.visibility;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.borderDefault,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit Course',
              style: TextStyle(
                color: c.text,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              style: TextStyle(color: c.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Course title',
                hintStyle: TextStyle(color: c.hint),
                filled: true,
                fillColor: c.fieldBg,
                prefixIcon: Icon(
                  Icons.book_outlined,
                  color: c.iconDefault,
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.borderDefault),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.borderDefault),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.borderFocus, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Visibility',
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                _VisToggle(
                  value: _visibility,
                  colors: c,
                  onChange: (v) => setState(() => _visibility = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  final t = _titleCtrl.text.trim();
                  if (t.isEmpty) return;
                  Navigator.pop(context, {
                    'title': t,
                    'visibility': _visibility,
                  });
                },
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Visibility toggle ─────────────────────────────────────────────────────────
class _VisToggle extends StatelessWidget {
  final String value;
  final AppColorScheme colors;
  final ValueChanged<String> onChange;

  const _VisToggle({
    required this.value,
    required this.colors,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      decoration: BoxDecoration(
        color: c.fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill('private', Icons.lock_outline, 'Private', c),
          _pill('public', Icons.public_outlined, 'Public', c),
        ],
      ),
    );
  }

  Widget _pill(String v, IconData icon, String label, AppColorScheme c) {
    final active = value == v;
    return GestureDetector(
      onTap: () => onChange(v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? Colors.white : c.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : c.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small icon button ─────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final AppColorScheme colors;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c.fieldBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.borderDefault),
        ),
        child: Icon(icon, color: c.iconDefault, size: 20),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final AppColorScheme colors;
  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.book_outlined, color: c.primary, size: 34),
            ),
            const Gap(16),
            Text(
              'No courses yet',
              style: TextStyle(
                color: c.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(8),
            Text(
              'Tap "+ Create" to add your first course.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.book_rounded, Icons.book_outlined, 'Subjects'),
      (Icons.style_rounded, Icons.style_outlined, 'Review'),
      (Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Stats'),
      (Icons.person_rounded, Icons.person_outlined, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final (activeIcon, inactiveIcon, label) = items[i];
              final isActive = current == i;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? c.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? activeIcon : inactiveIcon,
                        color: isActive ? c.primary : c.iconDefault,
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          color: isActive ? c.primary : c.iconDefault,
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Placeholder tab ───────────────────────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final int index;
  const _PlaceholderTab({required this.index});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const labels = ['Home', 'Subjects', 'Review', 'Statistics', 'Profile'];
    return Center(
      child: Text(
        labels[index],
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
