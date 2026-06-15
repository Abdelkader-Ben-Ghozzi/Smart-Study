// lib/screens/focus_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/focus_provider.dart';
import '../theme/app_colors.dart';
import '../models/focus_session.dart';
import 'focus_settings_screen.dart';

class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late AnimationController _pulseCtrl;
  bool _showStopOverlay = false;

  static const _platform = MethodChannel('com.example.app1/focus');

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = ref.read(activeFocusProvider);
      if (s.phase != FocusPhase.active) return;
      ref.read(activeFocusProvider.notifier).tick();
      final updated = ref.read(activeFocusProvider);
      if (updated.remainingSeconds == 0) {
        _ticker?.cancel();
        _handleComplete();
      }
    });
  }

  Future<void> _handleComplete() async {
    final streak = await ref
        .read(activeFocusProvider.notifier)
        .completeSession();
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    // Stop overlay bubble
    try {
      await _platform.invokeMethod('stopOverlay');
    } catch (_) {}

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompletionDialog(
        streak: streak,
        onHome: () {
          if (!mounted) return;
          Navigator.of(context).pop();
          ref.read(activeFocusProvider.notifier).reset();
        },
      ),
    );
  }

  Future<void> _onSwitchTapped() async {
    final phase = ref.read(activeFocusProvider).phase;
    if (phase == FocusPhase.active) {
      setState(() => _showStopOverlay = true);
      return;
    }

    final settings = ref.read(focusSettingsProvider).valueOrNull;
    if (settings == null || settings.blockedApps.isEmpty) {
      final c = AppColors.of(context);
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: c.borderDefault),
          ),
          title: Text(
            'No apps blocked',
            style: TextStyle(color: c.text, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Add apps to block in Focus Settings before starting a session.',
            style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const FocusSettingsScreen(startOnSave: false),
                  ),
                );
              },
              child: const Text(
                'Go to Settings',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final started = await ref
        .read(activeFocusProvider.notifier)
        .startSession(settings.durationMinutes, settings.blockedApps);

    if (!mounted) return;
    if (started) {
      _ticker?.cancel();
      _startTicker();
      HapticFeedback.mediumImpact();

      // Start overlay bubble
      try {
        final durationMillis = settings.durationMinutes * 60 * 1000;
        await _platform.invokeMethod('startOverlay', {
          'duration_millis': durationMillis,
        });
      } catch (_) {}
    } else {
      final c = AppColors.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not start session. Check connection.'),
          backgroundColor: c.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final session = ref.watch(activeFocusProvider);
    final statsAsync = ref.watch(focusStatsProvider);
    final settings = ref.watch(focusSettingsProvider).valueOrNull;
    final isActive = session.phase == FocusPhase.active;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: c.bg,
                  floating: true,
                  elevation: 0,
                  title: Text(
                    'Focus Mode',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.tune_rounded, color: c.iconDefault),
                      tooltip: 'Settings',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const FocusSettingsScreen(startOnSave: false),
                        ),
                      ),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _FocusCard(
                        isActive: isActive,
                        session: session,
                        pulseCtrl: _pulseCtrl,
                        settings: settings,
                        onSwitchTapped: _onSwitchTapped,
                      ),
                      const SizedBox(height: 16),
                      statsAsync.when(
                        loading: () => const _StatsLoading(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (stats) => _StatsSection(stats: stats),
                      ),
                      const SizedBox(height: 16),
                      _SettingsSummaryCard(
                        settings: settings,
                        onEdit: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const FocusSettingsScreen(startOnSave: false),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),

            if (_showStopOverlay)
              _HoldToStopOverlay(
                onStopped: () async {
                  setState(() => _showStopOverlay = false);
                  _ticker?.cancel();

                  // Stop overlay bubble
                  try {
                    await _platform.invokeMethod('stopOverlay');
                  } catch (_) {}

                  final streak = await ref
                      .read(activeFocusProvider.notifier)
                      .abandonSession();
                  ref.read(activeFocusProvider.notifier).reset();
                  _startTicker();
                  if (!mounted) return;
                  final c = AppColors.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        streak == 0
                            ? 'Session ended. Streak reset.'
                            : 'Session ended. Streak: $streak days.',
                      ),
                      backgroundColor: c.error.withOpacity(0.9),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                onDismissed: () => setState(() => _showStopOverlay = false),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Focus card ───────────────────────────────────────────────────────────────
class _FocusCard extends StatelessWidget {
  final bool isActive;
  final ActiveFocusState session;
  final AnimationController pulseCtrl;
  final FocusSettings? settings;
  final VoidCallback onSwitchTapped;

  const _FocusCard({
    required this.isActive,
    required this.session,
    required this.pulseCtrl,
    required this.settings,
    required this.onSwitchTapped,
  });

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final progress = session.totalSeconds == 0
        ? 0.0
        : 1 - (session.remainingSeconds / session.totalSeconds);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? c.primary.withOpacity(0.5) : c.cardBorder,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FadeTransition(
                opacity: isActive
                    ? pulseCtrl.drive(Tween(begin: 0.3, end: 1.0))
                    : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? c.success : c.iconDefault,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isActive ? 'Focus active' : 'Focus is off',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onSwitchTapped,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 52,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? c.primary : c.borderDefault,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    alignment: isActive
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                _fmt(session.remainingSeconds),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'remaining · ${session.progressPercent}% done',
                style: TextStyle(fontSize: 12, color: c.subtitle),
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: c.borderDefault,
                valueColor: AlwaysStoppedAnimation<Color>(c.primary),
              ),
            ),
            const SizedBox(height: 16),
            if (session.blockedPackages.isNotEmpty) ...[
              Text(
                'BLOCKING',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  color: c.subtitle,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: session.blockedPackages.map((pkg) {
                  final name = pkg.contains('.') ? pkg.split('.').last : pkg;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: c.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.error.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: c.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Text(
              settings?.blockedApps.isEmpty ?? true
                  ? 'Set up apps to block, then tap the switch'
                  : '${settings!.blockedApps.length} apps · ${settings!.durationMinutes}min session',
              style: TextStyle(fontSize: 12, color: c.subtitle),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stats section ─────────────────────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  final FocusStats stats;
  const _StatsSection({required this.stats});

  String _fmtMin(int m) {
    if (m == 0) return '0m';
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'FOCUS STATS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.9,
              color: c.subtitle,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _BigStatCard(
                value: _fmtMin(stats.todayMinutes),
                label: 'Today',
                icon: Icons.today_rounded,
                color: c.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BigStatCard(
                value: _fmtMin(stats.weekMinutes),
                label: 'This week',
                icon: Icons.date_range_rounded,
                color: const Color(0xFF7C5CBF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricPill(
                value: '${(stats.completionRate * 100).round()}%',
                label: 'Completion',
                rate: stats.completionRate,
                showBar: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricPill(
                value: '${stats.totalSessions}',
                label: 'Sessions',
                showBar: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricPill(
                value: '${stats.streak} 🔥',
                label: 'Streak',
                showBar: false,
              ),
            ),
          ],
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
  const _BigStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: c.text,
              fontFeatures: const [FontFeature.tabularFigures()],
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: c.subtitle)),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String value;
  final String label;
  final bool showBar;
  final double rate;
  const _MetricPill({
    required this.value,
    required this.label,
    required this.showBar,
    this.rate = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: c.subtitle)),
          if (showBar) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: rate.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: c.borderDefault,
                valueColor: AlwaysStoppedAnimation<Color>(c.success),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 80,
      child: Center(
        child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
      ),
    );
  }
}

class _SettingsSummaryCard extends StatelessWidget {
  final FocusSettings? settings;
  final VoidCallback onEdit;
  const _SettingsSummaryCard({this.settings, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dur = settings?.durationMinutes ?? 50;
    final blocked = settings?.blockedApps.length ?? 0;
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderDefault),
        ),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, size: 16, color: c.iconDefault),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${dur}min session · $blocked apps blocked',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.iconDefault, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Hold-to-stop overlay ──────────────────────────────────────────────────────
class _HoldToStopOverlay extends StatefulWidget {
  final VoidCallback onStopped;
  final VoidCallback onDismissed;
  const _HoldToStopOverlay({
    required this.onStopped,
    required this.onDismissed,
  });

  @override
  State<_HoldToStopOverlay> createState() => _HoldToStopOverlayState();
}

class _HoldToStopOverlayState extends State<_HoldToStopOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _holdCtrl;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _holdCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _holdCtrl.dispose();
    super.dispose();
  }

  void _startHold() {
    HapticFeedback.lightImpact();
    _holdCtrl.forward(from: 0);
    _holdTimer = Timer(const Duration(seconds: 3), () {
      HapticFeedback.heavyImpact();
      widget.onStopped();
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onDismissed,
        child: Container(
          color: Colors.black.withOpacity(0.6),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.error.withOpacity(0.4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _holdCtrl,
                          builder: (_, __) => CircularProgressIndicator(
                            value: _holdCtrl.value,
                            strokeWidth: 6,
                            backgroundColor: c.borderDefault,
                            valueColor: AlwaysStoppedAnimation<Color>(c.error),
                          ),
                        ),
                        Icon(Icons.stop_rounded, size: 28, color: c.error),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Stop focus session?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will break your streak. Hold the button below for 3 seconds to confirm.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onLongPressStart: (_) => _startHold(),
                    onLongPressEnd: (_) => _cancelHold(),
                    onLongPressCancel: _cancelHold,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: c.error,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Hold to stop',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: widget.onDismissed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.textSecondary,
                        side: BorderSide(color: c.borderDefault),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Keep going'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Completion dialog ─────────────────────────────────────────────────────────
class _CompletionDialog extends StatelessWidget {
  final int streak;
  final VoidCallback onHome;
  const _CompletionDialog({required this.streak, required this.onHome});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: c.success.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: c.success.withOpacity(0.4)),
              ),
              child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Session complete!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '🔥 Streak: $streak day${streak == 1 ? '' : 's'} — kept!',
              style: TextStyle(fontSize: 14, color: c.success),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
