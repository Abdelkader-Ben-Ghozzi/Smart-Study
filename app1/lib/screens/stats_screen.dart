// lib/screens/stats_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';
import '../providers/stats_provider.dart';
import '../providers/focus_provider.dart';
import '../services/stats_api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shimmer_box.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: statsAsync.when(
          loading: () => _ShimmerStats(colors: c),
          error: (_, __) =>
              _ErrorState(colors: c, onRetry: () => ref.refresh(statsProvider)),
          data: (data) => data == null
              ? _ErrorState(
                  colors: c,
                  onRetry: () => ref.refresh(statsProvider),
                )
              : _StatsBody(
                  data: data,
                  colors: c,
                  onRefresh: () {
                    ref.refresh(statsProvider);
                    ref.refresh(focusStatsProvider);
                  },
                ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────
class _StatsBody extends StatelessWidget {
  final StatsData data;
  final AppColorScheme colors;
  final VoidCallback onRefresh;

  const _StatsBody({
    required this.data,
    required this.colors,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;

    return RefreshIndicator(
      color: c.primary,
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistics',
                        style: TextStyle(
                          color: c.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Your learning overview',
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onRefresh,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.fieldBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.borderDefault),
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        color: c.iconDefault,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Top summary row ──
            _TopRow(data: data, colors: c),
            const Gap(20),

            // ── Focus stats ──
            _SectionTitle(
              label: 'Focus Mode',
              icon: Icons.timer_outlined,
              colors: c,
            ),
            const Gap(12),
            _FocusStatsSection(data: data, colors: c),
            const Gap(20),

            // ── Activity chart ──
            _SectionTitle(
              label: 'Activity',
              icon: Icons.bar_chart_rounded,
              colors: c,
            ),
            const Gap(12),
            _ActivityChart(activity: data.activity, colors: c),
            const Gap(20),

            // ── AI breakdown ──
            _SectionTitle(
              label: 'AI Generations',
              icon: Icons.auto_awesome_rounded,
              colors: c,
            ),
            const Gap(12),
            _AiBreakdown(ai: data.ai, colors: c),
            const Gap(20),

            // ── Sources breakdown ──
            _SectionTitle(
              label: 'Uploaded Sources',
              icon: Icons.folder_outlined,
              colors: c,
            ),
            const Gap(12),
            _SourcesBreakdown(sources: data.sources, colors: c),
            const Gap(20),

            // ── Recent activity ──
            if (data.recentActivity.isNotEmpty) ...[
              _SectionTitle(
                label: 'Recent Activity',
                icon: Icons.history_rounded,
                colors: c,
              ),
              const Gap(12),
              _RecentActivity(items: data.recentActivity, colors: c),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Focus stats section ───────────────────────────────────────────────────────
// Reads from StatsData.focus (backend /stats endpoint)
// so it shows the correct per-user streak without a separate API call.
class _FocusStatsSection extends StatelessWidget {
  final StatsData data;
  final AppColorScheme colors;

  const _FocusStatsSection({required this.data, required this.colors});

  String _fmtMin(int m) {
    if (m == 0) return '0m';
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final focus = data.focus;
    final streak = (focus['streak'] as num?)?.toInt() ?? 0;
    final todayMinutes = (focus['today_minutes'] as num?)?.toInt() ?? 0;
    final totalSessions =
        (focus['total_completed_sessions'] as num?)?.toInt() ?? 0;

    // Weekly focus activity from backend
    final weeklyRaw = focus['weekly_focus_activity'] as List<dynamic>? ?? [];
    final weekly = weeklyRaw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final maxMins = weekly
        .map((e) => (e['mins'] as num?)?.toInt() ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    final effectiveMax = maxMins == 0 ? 1 : maxMins;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        children: [
          // ── Streak banner with Lottie fire ──────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                // Lottie fire when streak > 0, static emoji otherwise
                SizedBox(
                  width: 52,
                  height: 52,
                  child: streak > 0
                      ? Lottie.asset(
                          'lotties/fire.json',
                          fit: BoxFit.contain,
                          repeat: true,
                        )
                      : const Center(
                          child: Text('🔥', style: TextStyle(fontSize: 32)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$streak',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF59E0B),
                              fontFeatures: [FontFeature.tabularFigures()],
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              streak == 1 ? 'day streak' : 'days streak',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: c.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        streak == 0
                            ? 'Complete a session to start your streak'
                            : 'Keep it up ',
                        style: TextStyle(fontSize: 11, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Today + total sessions ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _FocusStatBox(
                  value: _fmtMin(todayMinutes),
                  label: 'Today',
                  icon: Icons.today_rounded,
                  color: c.primary,
                  colors: c,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FocusStatBox(
                  value: '$totalSessions',
                  label: 'Sessions',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF10B981),
                  colors: c,
                ),
              ),
            ],
          ),

          // ── Weekly mini bar chart ────────────────────────────────────────
          if (weekly.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weekly.map((day) {
                final mins = (day['mins'] as num?)?.toInt() ?? 0;
                final label = day['day'] as String? ?? '';
                final ratio = mins / effectiveMax;
                final active = mins > 0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (mins > 0)
                          Text(
                            mins < 60 ? '${mins}m' : '${mins ~/ 60}h',
                            style: TextStyle(
                              color: c.primary,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          const SizedBox(height: 11),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          height: (48 * ratio).clamp(3.0, 48.0),
                          decoration: BoxDecoration(
                            color: active
                                ? c.primary
                                : c.borderDefault.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          label,
                          style: TextStyle(color: c.textSecondary, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _FocusStatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final AppColorScheme colors;

  const _FocusStatBox({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: c.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Top summary row ───────────────────────────────────────────────────────────
class _TopRow extends StatelessWidget {
  final StatsData data;
  final AppColorScheme colors;
  const _TopRow({required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Row(
      children: [
        Expanded(
          child: _BigStatCard(
            value: '${data.courses['total'] ?? 0}',
            label: 'Courses',
            icon: Icons.book_rounded,
            color: const Color(0xFF3055E7),
            colors: c,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BigStatCard(
            value: '${data.sources['total'] ?? 0}',
            label: 'Sources',
            icon: Icons.upload_file_rounded,
            color: const Color(0xFF10B981),
            colors: c,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BigStatCard(
            value: '${data.ai['total_generations'] ?? 0}',
            label: 'AI Gens',
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF7C3AED),
            colors: c,
          ),
        ),
      ],
    );
  }
}

class _BigStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final AppColorScheme colors;

  const _BigStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: c.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Activity chart ────────────────────────────────────────────────────────────
class _ActivityChart extends StatelessWidget {
  final List<Map<String, dynamic>> activity;
  final AppColorScheme colors;
  const _ActivityChart({required this.activity, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final maxCount = activity
        .map((e) => (e['count'] as int? ?? 0))
        .fold(0, (a, b) => a > b ? a : b);
    final effectiveMax = maxCount == 0 ? 1 : maxCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 7 days',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: activity.map((day) {
                final count = day['count'] as int? ?? 0;
                final label = day['date'] as String? ?? '';
                final ratio = count / effectiveMax;
                final active = count > 0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (count > 0)
                          Text(
                            '$count',
                            style: TextStyle(
                              color: c.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          height: (60 * ratio).clamp(4.0, 60.0),
                          decoration: BoxDecoration(
                            color: active
                                ? c.primary
                                : c.borderDefault.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI breakdown ──────────────────────────────────────────────────────────────
class _AiBreakdown extends StatelessWidget {
  final Map<String, dynamic> ai;
  final AppColorScheme colors;
  const _AiBreakdown({required this.ai, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final total = (ai['total_generations'] as int? ?? 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        children: [
          if (total > 0) ...[
            _StackedBar(
              segments: [
                _Segment(
                  value: ai['flashcard_sets'] as int? ?? 0,
                  total: total,
                  color: const Color(0xFF7C3AED),
                ),
                _Segment(
                  value: ai['summaries'] as int? ?? 0,
                  total: total,
                  color: const Color(0xFF0EA5E9),
                ),
                _Segment(
                  value: ai['quiz_sets'] as int? ?? 0,
                  total: total,
                  color: const Color(0xFF10B981),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _AiRow(
            icon: Icons.style_outlined,
            label: 'Flashcard Sets',
            value: '${ai['flashcard_sets'] ?? 0}',
            sub: '${ai['flashcard_items'] ?? 0} cards total',
            color: const Color(0xFF7C3AED),
            colors: c,
          ),
          const SizedBox(height: 10),
          _AiRow(
            icon: Icons.auto_awesome_outlined,
            label: 'Summaries',
            value: '${ai['summaries'] ?? 0}',
            sub: 'generated',
            color: const Color(0xFF0EA5E9),
            colors: c,
          ),
          const SizedBox(height: 10),
          _AiRow(
            icon: Icons.quiz_outlined,
            label: 'Quiz Sets',
            value: '${ai['quiz_sets'] ?? 0}',
            sub: '${ai['quiz_questions'] ?? 0} questions total',
            color: const Color(0xFF10B981),
            colors: c,
          ),
        ],
      ),
    );
  }
}

class _Segment {
  final int value;
  final int total;
  final Color color;
  const _Segment({
    required this.value,
    required this.total,
    required this.color,
  });
}

class _StackedBar extends StatelessWidget {
  final List<_Segment> segments;
  const _StackedBar({required this.segments});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: Row(
          children: segments.map((s) {
            final flex = s.total > 0 ? s.value : 0;
            return flex > 0
                ? Flexible(
                    flex: flex,
                    child: Container(color: s.color),
                  )
                : const SizedBox.shrink();
          }).toList(),
        ),
      ),
    );
  }
}

class _AiRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final AppColorScheme colors;
  const _AiRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: c.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: c.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ── Sources breakdown ─────────────────────────────────────────────────────────
class _SourcesBreakdown extends StatelessWidget {
  final Map<String, dynamic> sources;
  final AppColorScheme colors;
  const _SourcesBreakdown({required this.sources, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final total = sources['total'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SourcePill(
              icon: Icons.picture_as_pdf_outlined,
              label: 'PDF',
              count: sources['pdf'] as int? ?? 0,
              total: total,
              color: const Color(0xFFE53935),
              colors: c,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SourcePill(
              icon: Icons.description_outlined,
              label: 'DOCX',
              count: sources['docx'] as int? ?? 0,
              total: total,
              color: const Color(0xFF1565C0),
              colors: c,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SourcePill(
              icon: Icons.image_outlined,
              label: 'Image',
              count: sources['image'] as int? ?? 0,
              total: total,
              color: const Color(0xFF10B981),
              colors: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final int total;
  final Color color;
  final AppColorScheme colors;
  const _SourcePill({
    required this.icon,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final pct = total > 0 ? (count / total) : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              color: c.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.toDouble(),
              backgroundColor: color.withOpacity(0.12),
              color: color,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent activity ───────────────────────────────────────────────────────────
class _RecentActivity extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final AppColorScheme colors;
  const _RecentActivity({required this.items, required this.colors});

  Color _colorFor(String tool) => switch (tool) {
    'flashcards' => const Color(0xFF7C3AED),
    'summary' => const Color(0xFF0EA5E9),
    _ => const Color(0xFF10B981),
  };

  IconData _iconFor(String tool) => switch (tool) {
    'flashcards' => Icons.style_outlined,
    'summary' => Icons.auto_awesome_outlined,
    _ => Icons.quiz_outlined,
  };

  String _labelFor(String tool) => switch (tool) {
    'flashcards' => 'Flashcards',
    'summary' => 'Summary',
    _ => 'Quiz',
  };

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final tool = item['tool'] as String? ?? 'qcm';
          final color = _colorFor(tool);
          return Column(
            children: [
              if (i > 0) Divider(height: 1, color: c.divider),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_iconFor(tool), color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String? ?? '',
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
                            _labelFor(tool),
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item['created_at'] as String? ?? '',
                      style: TextStyle(color: c.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String label;
  final IconData icon;
  final AppColorScheme colors;
  const _SectionTitle({
    required this.label,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Row(
      children: [
        Icon(icon, color: c.primary, size: 17),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: c.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Shimmer loading ───────────────────────────────────────────────────────────
class _ShimmerStats extends StatelessWidget {
  final AppColorScheme colors;
  const _ShimmerStats({required this.colors});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Gap(20),
          Row(
            children: [
              Expanded(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 90,
                  radius: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 90,
                  radius: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 90,
                  radius: 16,
                ),
              ),
            ],
          ),
          const Gap(20),
          ShimmerBox(width: double.infinity, height: 200, radius: 16),
          const Gap(20),
          ShimmerBox(width: double.infinity, height: 130, radius: 16),
          const Gap(20),
          ShimmerBox(width: double.infinity, height: 160, radius: 16),
          const Gap(20),
          ShimmerBox(width: double.infinity, height: 100, radius: 16),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final AppColorScheme colors;
  final VoidCallback onRetry;
  const _ErrorState({required this.colors, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, color: c.iconDefault, size: 44),
          const Gap(12),
          Text(
            'Failed to load stats',
            style: TextStyle(
              color: c.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(6),
          Text(
            'Pull to refresh or tap retry',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          const Gap(20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onRetry,
            child: const Text(
              'Retry',
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
}
