import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';

import '../models/course.dart';
import '../models/course_details_models.dart';
import '../providers/course_details_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/shimmer_box.dart';
import '../screens/offline_screen.dart'; // ← ADD THIS

// ─────────────────────────────────────────────────────────────────────────────
// CourseDetailScreen
// ─────────────────────────────────────────────────────────────────────────────
class CourseDetailScreen extends ConsumerWidget {
  final Course course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: _CourseAppBar(course: course, colors: c),
        body: TabBarView(
          children: [
            _SourcesTab(course: course),
            _AiToolsTab(course: course),
          ],
        ),
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────
class _CourseAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  final Course course;
  final AppColorScheme colors;
  const _CourseAppBar({required this.course, required this.colors});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 52);

  @override
  ConsumerState<_CourseAppBar> createState() => _CourseAppBarState();
}

class _CourseAppBarState extends ConsumerState<_CourseAppBar> {
  bool _saving = false;

  // ── Save course + all AI history to SharedPreferences ─────────────────────
  Future<void> _saveOffline(BuildContext context) async {
    setState(() => _saving = true);
    final c = widget.colors;

    try {
      // Get the already-loaded AI history from the provider cache
      final historyAsync = ref.read(aiHistoryProvider(widget.course.id));
      final items = historyAsync.value ?? [];

      // Map GeneratedContent → SavedContentLocal
      final contents = items.map((item) {
        Map<String, dynamic> contentJson;

        switch (item.tool) {
          case AiTool.flashcards:
            contentJson = {
              'cards': item.flashcards
                  .map((f) => {'question': f.front, 'answer': f.back})
                  .toList(),
            };
            break;
          case AiTool.summary:
            final s = item.summary;
            contentJson = {
              'overview': s?.overview ?? '',
              'key_points': s?.keyPoints ?? [],
              'sections':
                  s?.sections
                      .map(
                        (sec) => {'title': sec.heading, 'content': sec.content},
                      )
                      .toList() ??
                  [],
            };
            break;
          case AiTool.qcm:
            contentJson = {
              'questions': item.questions
                  .map(
                    (q) => {
                      'question': q.question,
                      'options': q.options,
                      'correct_index': q.correctIndex,
                    },
                  )
                  .toList(),
            };
            break;
        }

        return SavedContentLocal(
          id: item.id,
          tool: item.tool.name, // 'flashcards' | 'summary' | 'qcm'
          content: contentJson,
          savedAt: DateTime.now(),
        );
      }).toList();

      // Build SavedCourseLocal
      final saved = SavedCourseLocal(
        id: widget.course.id,
        courseId: widget.course.id,
        title: widget.course.title,
        ownerName: widget.course.ownerName ?? 'Unknown',
        isPublic: widget.course.isPublic,
        savedAt: DateTime.now(),
        contents: contents,
      );

      await LocalStorage.saveCourse(saved);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  contents.isEmpty
                      ? 'Course saved (no AI content yet)'
                      : 'Course + ${contents.length} AI item(s) saved offline ✓',
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save offline: $e'),
            backgroundColor: widget.colors.borderError,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return AppBar(
      backgroundColor: c.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.text, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.course.title,
            style: TextStyle(
              color: c.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Icon(
                widget.course.isMine
                    ? Icons.person_outline
                    : Icons.public_outlined,
                size: 11,
                color: c.textSecondary,
              ),
              const SizedBox(width: 3),
              Text(
                widget.course.isMine ? 'My course' : widget.course.ownerName,
                style: TextStyle(color: c.textSecondary, fontSize: 11),
              ),
              if (widget.course.isMine) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Owner',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      // ── Download button ────────────────────────────────────────────────────
      actions: [
        _saving
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: c.primary,
                    strokeWidth: 2,
                  ),
                ),
              )
            : IconButton(
                icon: Icon(Icons.download_rounded, color: c.text, size: 22),
                tooltip: 'Save for offline',
                onPressed: () => _saveOffline(context),
              ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: c.fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.borderDefault),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: c.subtitle,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Sources'),
                Tab(text: 'AI Tools'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOURCES TAB
// ─────────────────────────────────────────────────────────────────────────────
class _SourcesTab extends ConsumerWidget {
  final Course course;
  const _SourcesTab({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final sourcesAsync = ref.watch(sourcesProvider(course.id));

    return Column(
      children: [
        if (course.isMine) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _UploadBar(course: course),
          ),
          const SizedBox(height: 4),
        ] else ...[
          _ReadOnlyBanner(colors: c),
        ],

        Expanded(
          child: sourcesAsync.when(
            loading: () => _shimmerList(),
            error: (_, __) => _CenteredMsg(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load sources',
              subtitle: 'Showing cached data if available',
              colors: c,
            ),
            data: (list) => list.isEmpty
                ? _CenteredMsg(
                    icon: Icons.upload_file_outlined,
                    title: 'No sources yet',
                    subtitle: course.isMine
                        ? 'Upload PDFs, DOCX or images to generate AI content'
                        : 'The course owner hasn\'t uploaded any sources yet',
                    colors: c,
                  )
                : RefreshIndicator(
                    color: c.primary,
                    onRefresh: () async =>
                        ref.refresh(sourcesProvider(course.id)),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _SourceTile(
                        source: list[i],
                        canDelete: course.isMine,
                        colors: c,
                        onDelete: () => ref
                            .read(sourcesProvider(course.id).notifier)
                            .delete(list[i].id),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _shimmerList() => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 4,
    itemBuilder: (_, __) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ShimmerBox(width: double.infinity, height: 64, radius: 12),
    ),
  );
}

// ── Read-only banner ──────────────────────────────────────────────────────────
class _ReadOnlyBanner extends StatelessWidget {
  final AppColorScheme colors;
  const _ReadOnlyBanner({required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, color: c.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'View-only mode — only the course owner can add resources',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Upload bar (owner only) ───────────────────────────────────────────────────
class _UploadBar extends ConsumerStatefulWidget {
  final Course course;
  const _UploadBar({required this.course});

  @override
  ConsumerState<_UploadBar> createState() => _UploadBarState();
}

class _UploadBarState extends ConsumerState<_UploadBar> {
  bool _uploading = false;

  Future<void> _pick(FileType type, List<String>? exts) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: exts,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _uploading = true);
    final res = await ref
        .read(sourcesProvider(widget.course.id).notifier)
        .upload(filePath: file.path!, fileName: file.name);
    if (!mounted) return;
    setState(() => _uploading = false);

    final c = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['success'] == true
              ? 'Uploaded successfully'
              : res['message'] ?? 'Upload failed',
        ),
        backgroundColor: res['success'] == true ? c.success : c.borderError,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (_uploading) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: c.fieldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.borderDefault),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: c.primary,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Uploading…',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _UploadBtn(
            icon: Icons.picture_as_pdf_outlined,
            label: 'PDF',
            color: const Color(0xFFE53935),
            onTap: () => _pick(FileType.custom, ['pdf']),
            colors: c,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _UploadBtn(
            icon: Icons.description_outlined,
            label: 'DOCX',
            color: const Color(0xFF1565C0),
            onTap: () => _pick(FileType.custom, ['doc', 'docx']),
            colors: c,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _UploadBtn(
            icon: Icons.image_outlined,
            label: 'Image',
            color: const Color(0xFF10B981),
            onTap: () => _pick(FileType.image, null),
            colors: c,
          ),
        ),
      ],
    );
  }
}

class _UploadBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final AppColorScheme colors;
  const _UploadBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
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

// ── Source tile ───────────────────────────────────────────────────────────────
class _SourceTile extends StatelessWidget {
  final CourseSource source;
  final bool canDelete;
  final AppColorScheme colors;
  final VoidCallback onDelete;
  const _SourceTile({
    required this.source,
    required this.canDelete,
    required this.colors,
    required this.onDelete,
  });

  Color get _typeColor => switch (source.type) {
    'pdf' => const Color(0xFFE53935),
    'docx' => const Color(0xFF1565C0),
    'image' => const Color(0xFF10B981),
    _ => const Color(0xFF888780),
  };
  IconData get _typeIcon => switch (source.type) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'docx' => Icons.description_outlined,
    'image' => Icons.image_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcon, color: _typeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  source.formattedSize,
                  style: TextStyle(color: c.subtitle, fontSize: 11),
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              icon: Icon(Icons.delete_outline, color: c.borderError, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI TOOLS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _AiToolsTab extends ConsumerWidget {
  final Course course;
  const _AiToolsTab({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final genState = ref.watch(generationProvider(course.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ToolCard(
                  tool: AiTool.flashcards,
                  icon: Icons.style_outlined,
                  color: const Color(0xFF7C3AED),
                  isOwner: course.isMine,
                  colors: c,
                  onTap: course.isMine
                      ? () => _openConfig(context, ref, AiTool.flashcards, c)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ToolCard(
                  tool: AiTool.summary,
                  icon: Icons.auto_awesome_outlined,
                  color: const Color(0xFF0EA5E9),
                  isOwner: course.isMine,
                  colors: c,
                  onTap: course.isMine
                      ? () => _openConfig(context, ref, AiTool.summary, c)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ToolCard(
                  tool: AiTool.qcm,
                  icon: Icons.quiz_outlined,
                  color: const Color(0xFF10B981),
                  isOwner: course.isMine,
                  colors: c,
                  onTap: course.isMine
                      ? () => _openConfig(context, ref, AiTool.qcm, c)
                      : null,
                ),
              ),
            ],
          ),

          const Gap(16),

          if (genState.status == GenerationStatus.loading)
            _GeneratingCard(colors: c),

          if (genState.status == GenerationStatus.error)
            _ErrorCard(
              message: genState.error ?? 'Unknown error',
              colors: c,
              onDismiss: () =>
                  ref.read(generationProvider(course.id).notifier).reset(),
            ),

          const Gap(8),

          _HistorySection(course: course, colors: c),
        ],
      ),
    );
  }

  void _openConfig(
    BuildContext context,
    WidgetRef ref,
    AiTool tool,
    AppColorScheme c,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiConfigSheet(tool: tool, course: course, colors: c),
    );
  }
}

// ── Tool card ─────────────────────────────────────────────────────────────────
class _ToolCard extends StatelessWidget {
  final AiTool tool;
  final IconData icon;
  final Color color;
  final bool isOwner;
  final AppColorScheme colors;
  final VoidCallback? onTap;

  const _ToolCard({
    required this.tool,
    required this.icon,
    required this.color,
    required this.isOwner,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final locked = !isOwner;
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: Opacity(
        opacity: locked ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.cardBorder),
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  if (locked)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: c.fieldBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.borderDefault),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          color: c.subtitle,
                          size: 9,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                tool.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Config sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AiConfigSheet extends ConsumerStatefulWidget {
  final AiTool tool;
  final Course course;
  final AppColorScheme colors;
  const _AiConfigSheet({
    required this.tool,
    required this.course,
    required this.colors,
  });

  @override
  ConsumerState<_AiConfigSheet> createState() => _AiConfigSheetState();
}

class _AiConfigSheetState extends ConsumerState<_AiConfigSheet> {
  int _count = 10;
  String _difficulty = 'medium';
  final Set<int> _selectedSourceIds = {};

  AppColorScheme get c => widget.colors;
  final _counts = [5, 10, 15, 20];
  final _difficulties = ['easy', 'medium', 'hard'];

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(sourcesProvider(widget.course.id));
    final sources =
        sourcesAsync.value?.where((s) => s.type != 'image').toList() ?? [];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SingleChildScrollView(
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
                'Configure ${widget.tool.label}',
                style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),

              // Source selection
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select sources to use',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (sources.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.fieldBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.borderDefault),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: c.subtitle, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'No text sources. Upload PDF or DOCX first.',
                        style: TextStyle(color: c.subtitle, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: c.fieldBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.borderDefault),
                  ),
                  child: Column(
                    children: sources.asMap().entries.map((e) {
                      final i = e.key;
                      final src = e.value;
                      final isSelected = _selectedSourceIds.contains(src.id);
                      return Column(
                        children: [
                          if (i > 0) Divider(height: 1, color: c.divider),
                          CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => setState(() {
                              if (isSelected) {
                                _selectedSourceIds.remove(src.id);
                              } else {
                                _selectedSourceIds.add(src.id);
                              }
                            }),
                            activeColor: c.primary,
                            checkColor: Colors.white,
                            title: Text(
                              src.name,
                              style: TextStyle(color: c.text, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              src.formattedSize,
                              style: TextStyle(color: c.subtitle, fontSize: 11),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            dense: true,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 16),

              // Count
              if (widget.tool != AiTool.summary) ...[
                Row(
                  children: [
                    Text(
                      'Number',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    ...(_counts.map(
                      (n) => GestureDetector(
                        onTap: () => setState(() => _count = n),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 40,
                          height: 32,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: _count == n ? c.primary : c.fieldBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _count == n ? c.primary : c.borderDefault,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$n',
                              style: TextStyle(
                                color: _count == n ? Colors.white : c.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Difficulty
              if (widget.tool != AiTool.summary) ...[
                Row(
                  children: [
                    Text(
                      'Difficulty',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    ...(_difficulties.map((d) {
                      final color = switch (d) {
                        'easy' => const Color(0xFF10B981),
                        'medium' => const Color(0xFFF59E0B),
                        _ => const Color(0xFFEF4444),
                      };
                      final active = _difficulty == d;
                      return GestureDetector(
                        onTap: () => setState(() => _difficulty = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: active ? color.withOpacity(0.15) : c.fieldBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active ? color : c.borderDefault,
                            ),
                          ),
                          child: Text(
                            d[0].toUpperCase() + d.substring(1),
                            style: TextStyle(
                              color: active ? color : c.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    })),
                  ],
                ),
              ],

              const SizedBox(height: 22),

              // Generate button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        sources.isEmpty || _selectedSourceIds.isEmpty
                        ? c.borderDefault
                        : c.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    _selectedSourceIds.isEmpty
                        ? 'Select at least one source'
                        : 'Generate ${widget.tool.label}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: _selectedSourceIds.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          ref
                              .read(
                                generationProvider(widget.course.id).notifier,
                              )
                              .generate(
                                tool: widget.tool,
                                count: _count,
                                difficulty: _difficulty,
                                sourceIds: _selectedSourceIds.toList(),
                              );
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History section
// ─────────────────────────────────────────────────────────────────────────────
class _HistorySection extends ConsumerWidget {
  final Course course;
  final AppColorScheme colors;
  const _HistorySection({required this.course, required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = colors;
    final history = ref.watch(aiHistoryProvider(course.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Generated content',
              style: TextStyle(
                color: c.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: c.iconDefault, size: 18),
              onPressed: () => ref.refresh(aiHistoryProvider(course.id)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 10),

        history.when(
          loading: () => Column(
            children: List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ShimmerBox(
                  width: double.infinity,
                  height: 58,
                  radius: 10,
                ),
              ),
            ),
          ),
          error: (_, __) => Text(
            'Could not load history',
            style: TextStyle(color: c.subtitle, fontSize: 13),
          ),
          data: (items) => items.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: c.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: c.iconDefault,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        course.isMine
                            ? 'No generated content yet. Use the tools above.'
                            : 'No generated content available yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.subtitle, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: items
                      .map(
                        (item) =>
                            _HistoryTile(item: item, course: course, colors: c),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

// ── History tile ──────────────────────────────────────────────────────────────
class _HistoryTile extends ConsumerWidget {
  final GeneratedContent item;
  final Course course;
  final AppColorScheme colors;
  const _HistoryTile({
    required this.item,
    required this.course,
    required this.colors,
  });

  Color get _color => switch (item.tool) {
    AiTool.flashcards => const Color(0xFF7C3AED),
    AiTool.summary => const Color(0xFF0EA5E9),
    AiTool.qcm => const Color(0xFF10B981),
  };
  IconData get _icon => switch (item.tool) {
    AiTool.flashcards => Icons.style_outlined,
    AiTool.summary => Icons.auto_awesome_outlined,
    AiTool.qcm => Icons.quiz_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContentViewerScreen(content: item, colors: c),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_icon, color: _color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(item),
                        style: TextStyle(color: c.subtitle, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: c.iconDefault,
                  size: 18,
                ),
                if (course.isMine) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () async {
                      final ok = await ref
                          .read(courseDetailApiProvider)
                          .deleteGeneratedContent(course.id, item.id);
                      if (ok) ref.refresh(aiHistoryProvider(course.id));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline,
                        color: c.borderError,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(GeneratedContent g) => switch (g.tool) {
    AiTool.flashcards =>
      '${g.flashcards.length} cards • ${g.options?['difficulty'] ?? ''}',
    AiTool.summary => '${g.summary?.keyPoints.length ?? 0} key points',
    AiTool.qcm =>
      '${g.questions.length} questions • ${g.options?['difficulty'] ?? ''}',
  };
}

// ── Generating card ───────────────────────────────────────────────────────────
class _GeneratingCard extends StatelessWidget {
  final AppColorScheme colors;
  const _GeneratingCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(color: c.primary, strokeWidth: 2.5),
          const SizedBox(height: 12),
          Text(
            'AI is generating your content…',
            style: TextStyle(
              color: c.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This may take 15–30 seconds',
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final AppColorScheme colors;
  final VoidCallback onDismiss;
  const _ErrorCard({
    required this.message,
    required this.colors,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.borderError.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderError.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: c.borderError, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: c.borderError, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: c.borderError, size: 16),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _CenteredMsg extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final AppColorScheme colors;
  const _CenteredMsg({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
  });

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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: c.primary, size: 30),
            ),
            const Gap(14),
            Text(
              title,
              style: TextStyle(
                color: c.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(6),
            Text(
              subtitle,
              style: TextStyle(color: c.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTENT VIEWER SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ContentViewerScreen extends StatelessWidget {
  final GeneratedContent content;
  final AppColorScheme colors;
  const ContentViewerScreen({
    super.key,
    required this.content,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.text, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          content.title,
          style: TextStyle(
            color: c.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: switch (content.tool) {
        AiTool.flashcards => _FlashcardsViewer(
          cards: content.flashcards,
          colors: c,
        ),
        AiTool.summary => _SummaryViewer(summary: content.summary, colors: c),
        AiTool.qcm => _QcmViewer(questions: content.questions, colors: c),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLASHCARDS VIEWER
// ─────────────────────────────────────────────────────────────────────────────
class _FlashcardsViewer extends StatefulWidget {
  final List<Flashcard> cards;
  final AppColorScheme colors;
  const _FlashcardsViewer({required this.cards, required this.colors});

  @override
  State<_FlashcardsViewer> createState() => _FlashcardsViewerState();
}

class _FlashcardsViewerState extends State<_FlashcardsViewer>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _flipped = false;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_flipped) {
      _ctrl.reverse().then((_) => setState(() => _flipped = false));
    } else {
      _ctrl.forward().then((_) => setState(() => _flipped = true));
    }
  }

  void _goTo(int i) {
    if (i < 0 || i >= widget.cards.length) return;
    if (_flipped) {
      _ctrl.reverse().then((_) {
        setState(() {
          _flipped = false;
          _index = i;
        });
      });
    } else {
      setState(() => _index = i);
    }
  }

  AppColorScheme get c => widget.colors;

  @override
  Widget build(BuildContext context) {
    final card = widget.cards[_index];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Text(
                '${_index + 1} / ${widget.cards.length}',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_index + 1) / widget.cards.length,
                    backgroundColor: c.fieldBg,
                    color: const Color(0xFF7C3AED),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _flipped ? 'Answer' : 'Question',
            style: TextStyle(
              color: _flipped ? const Color(0xFF7C3AED) : c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _flip,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, __) {
                  final showBack = _anim.value > 0.5;
                  final angle = _anim.value * math.pi;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: showBack
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(math.pi),
                            child: _CardFace(
                              text: card.back,
                              isBack: true,
                              colors: c,
                            ),
                          )
                        : _CardFace(text: card.front, isBack: false, colors: c),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Row(
            children: [
              Expanded(
                child: _NavBtn(
                  label: 'Previous',
                  icon: Icons.arrow_back_ios_rounded,
                  enabled: _index > 0,
                  colors: c,
                  onTap: () => _goTo(_index - 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NavBtn(
                  label: 'Next',
                  icon: Icons.arrow_forward_ios_rounded,
                  iconTrailing: true,
                  enabled: _index < widget.cards.length - 1,
                  colors: c,
                  onTap: () => _goTo(_index + 1),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_outlined, color: c.hint, size: 14),
              const SizedBox(width: 4),
              Text(
                'Tap card to flip',
                style: TextStyle(color: c.hint, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardFace extends StatelessWidget {
  final String text;
  final bool isBack;
  final AppColorScheme colors;
  const _CardFace({
    required this.text,
    required this.isBack,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final color = isBack ? const Color(0xFF7C3AED) : c.primary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            text,
            style: TextStyle(
              color: c.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY VIEWER
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryViewer extends StatelessWidget {
  final Summary? summary;
  final AppColorScheme colors;
  const _SummaryViewer({required this.summary, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    if (summary == null) {
      return Center(
        child: Text('No summary data', style: TextStyle(color: c.subtitle)),
      );
    }
    final s = summary!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.title,
            style: TextStyle(
              color: c.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.primary.withOpacity(0.15)),
            ),
            child: Text(
              s.overview,
              style: TextStyle(color: c.text, fontSize: 14, height: 1.7),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            label: 'Key Points',
            icon: Icons.star_outline_rounded,
            colors: c,
          ),
          const SizedBox(height: 10),
          ...s.keyPoints.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: TextStyle(
                          color: c.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (s.sections.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionHeader(
              label: 'Sections',
              icon: Icons.list_alt_outlined,
              colors: c,
            ),
            const SizedBox(height: 10),
            ...s.sections.map(
              (sec) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sec.heading,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sec.content,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (s.conclusion.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SectionHeader(
              label: 'Conclusion',
              icon: Icons.flag_outlined,
              colors: c,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                ),
              ),
              child: Text(
                s.conclusion,
                style: TextStyle(
                  color: c.text,
                  fontSize: 14,
                  height: 1.7,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final AppColorScheme colors;
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Row(
      children: [
        Icon(icon, color: c.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: c.text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QCM VIEWER
// ─────────────────────────────────────────────────────────────────────────────
class _QcmViewer extends StatefulWidget {
  final List<QcmQuestion> questions;
  final AppColorScheme colors;
  const _QcmViewer({required this.questions, required this.colors});

  @override
  State<_QcmViewer> createState() => _QcmViewerState();
}

class _QcmViewerState extends State<_QcmViewer> {
  int _current = 0;
  final Map<int, int> _answers = {};
  bool _showResult = false;

  AppColorScheme get c => widget.colors;
  List<QcmQuestion> get _qs => widget.questions;
  bool get _answered => _answers.containsKey(_current);
  bool get _isLast => _current == _qs.length - 1;
  int get _score =>
      _answers.entries.where((e) => e.value == _qs[e.key].correctIndex).length;

  void _select(int i) {
    if (_answered) return;
    setState(() => _answers[_current] = i);
  }

  void _next() {
    if (_isLast) {
      setState(() => _showResult = true);
    } else {
      setState(() => _current++);
    }
  }

  void _prev() {
    if (_current > 0) setState(() => _current--);
  }

  void _restart() => setState(() {
    _current = 0;
    _answers.clear();
    _showResult = false;
  });

  @override
  Widget build(BuildContext context) {
    if (_showResult) return _buildScore();

    final q = _qs[_current];
    final selected = _answers[_current];
    final isAnswered = selected != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Text(
                '${_current + 1} / ${_qs.length}',
                style: TextStyle(color: c.textSecondary, fontSize: 13),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_current + 1) / _qs.length,
                    backgroundColor: c.fieldBg,
                    color: const Color(0xFF10B981),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_score/${_answers.length}',
                style: TextStyle(
                  color: c.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.cardBorder),
                  ),
                  child: Text(
                    q.question,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...q.options.asMap().entries.map((e) {
                  final i = e.key;
                  final opt = e.value;
                  final isSelected = selected == i;
                  final isCorrect = i == q.correctIndex;

                  Color? borderColor = c.borderDefault;
                  Color? bgColor = c.cardBg;
                  Widget? trailing;

                  if (isAnswered) {
                    if (isCorrect) {
                      bgColor = const Color(0xFF10B981).withOpacity(0.08);
                      borderColor = const Color(0xFF10B981).withOpacity(0.5);
                      trailing = const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      );
                    } else if (isSelected) {
                      bgColor = c.borderError.withOpacity(0.06);
                      borderColor = c.borderError.withOpacity(0.4);
                      trailing = Icon(
                        Icons.cancel_rounded,
                        color: c.borderError,
                        size: 20,
                      );
                    }
                  } else if (isSelected) {
                    borderColor = c.primary;
                    bgColor = c.primary.withOpacity(0.06);
                  }

                  return GestureDetector(
                    onTap: isAnswered ? null : () => _select(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor!, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAnswered && isCorrect
                                  ? const Color(0xFF10B981).withOpacity(0.15)
                                  : isSelected && !isAnswered
                                  ? c.primary.withOpacity(0.12)
                                  : c.fieldBg,
                              border: Border.all(
                                color: isAnswered && isCorrect
                                    ? const Color(0xFF10B981)
                                    : isSelected && !isAnswered
                                    ? c.primary
                                    : c.borderDefault,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: TextStyle(
                                  color: isAnswered && isCorrect
                                      ? const Color(0xFF10B981)
                                      : isSelected && !isAnswered
                                      ? c.primary
                                      : c.subtitle,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              opt,
                              style: TextStyle(
                                color: c.text,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (trailing != null) trailing,
                        ],
                      ),
                    ),
                  );
                }),
                if (isAnswered) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: c.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q.explanation,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Row(
            children: [
              if (_current > 0) ...[
                Expanded(
                  child: _NavBtn(
                    label: 'Previous',
                    icon: Icons.arrow_back_ios_rounded,
                    enabled: true,
                    colors: c,
                    onTap: _prev,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _NavBtn(
                  label: _isLast ? 'See Results' : 'Next',
                  icon: _isLast
                      ? Icons.flag_rounded
                      : Icons.arrow_forward_ios_rounded,
                  iconTrailing: true,
                  enabled: isAnswered,
                  colors: c,
                  onTap: _next,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScore() {
    final pct = _score / _qs.length;
    final color = pct >= 0.7
        ? const Color(0xFF10B981)
        : pct >= 0.4
        ? const Color(0xFFF59E0B)
        : c.borderError;
    final message = pct >= 0.7
        ? 'Great job! 🎉'
        : pct >= 0.4
        ? 'Keep practising! 📚'
        : 'Review the material and try again 💪';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              border: Border.all(color: color, width: 3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_score/${_qs.length}',
                  style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${(pct * 100).round()}%',
                  style: TextStyle(color: color, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: c.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 28),
          ..._qs.asMap().entries.map((e) {
            final i = e.key;
            final q = e.value;
            final answered = _answers[i];
            final correct = answered == q.correctIndex;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: correct
                      ? const Color(0xFF10B981).withOpacity(0.3)
                      : c.borderError.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        correct
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: correct
                            ? const Color(0xFF10B981)
                            : c.borderError,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Q${i + 1}: ${q.question}',
                          style: TextStyle(
                            color: c.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (!correct && answered != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Your answer: ${q.options[answered]}',
                      style: TextStyle(color: c.borderError, fontSize: 12),
                    ),
                    Text(
                      'Correct: ${q.options[q.correctIndex]}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Retake Quiz',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _restart,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared nav button ─────────────────────────────────────────────────────────
class _NavBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool iconTrailing;
  final bool enabled;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _NavBtn({
    required this.label,
    required this.icon,
    this.iconTrailing = false,
    required this.enabled,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        decoration: BoxDecoration(
          color: enabled ? c.primary : c.fieldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: enabled ? c.primary : c.borderDefault),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!iconTrailing) ...[
              Icon(icon, color: enabled ? Colors.white : c.subtitle, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : c.subtitle,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (iconTrailing) ...[
              const SizedBox(width: 6),
              Icon(icon, color: enabled ? Colors.white : c.subtitle, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}
