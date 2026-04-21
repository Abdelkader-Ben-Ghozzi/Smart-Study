// lib/screens/active_focus_screen.dart
//
// Back button / swipe-back works — takes you back to FocusPage.
// The session keeps running (timer in provider keeps ticking via FocusPage).
// Full AppColors.of(context) — no hardcoded colors.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/focus_provider.dart';
import '../theme/app_colors.dart';

class ActiveFocusScreen extends ConsumerStatefulWidget {
  final List<String> blockedPackages;

  const ActiveFocusScreen({super.key, required this.blockedPackages});

  @override
  ConsumerState<ActiveFocusScreen> createState() => _ActiveFocusScreenState();
}

class _ActiveFocusScreenState extends ConsumerState<ActiveFocusScreen>
    with TickerProviderStateMixin {
  Timer? _ticker;
  late AnimationController _pulseCtrl;
  late AnimationController _holdCtrl;
  Timer? _holdTimer;
  bool _showAbandon = false;
  bool _completing = false;

  static const _motivations = [
    '🧠 Session started — apps are blocked.',
    '💪 10 minutes in. Momentum is building.',
    '⚡ Deep work activated. Stay locked in.',
    '🎯 Halfway there — you\'ve got this.',
    '🔥 Almost done. Finish strong!',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _holdCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _holdTimer?.cancel();
    _pulseCtrl.dispose();
    _holdCtrl.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(activeFocusProvider.notifier).tick();
      final s = ref.read(activeFocusProvider);
      if (s.remainingSeconds == 0 && !_completing) {
        _ticker?.cancel();
        _handleComplete();
      }
    });
  }

  Future<void> _handleComplete() async {
    if (_completing) return;
    setState(() => _completing = true);
    final streak = await ref
        .read(activeFocusProvider.notifier)
        .completeSession();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _showCompletionDialog(streak);
  }

  void _showCompletionDialog(int streak) {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CompletionDialog(
        streak: streak,
        colors: c,
        onHome: () {
          Navigator.of(ctx).pop();
          // Pop back to FocusPage (not all the way to HomeScreen)
          Navigator.of(context).pop();
          ref.read(activeFocusProvider.notifier).reset();
        },
      ),
    );
  }

  void _startHold() {
    HapticFeedback.lightImpact();
    _holdCtrl.forward(from: 0);
    _holdTimer = Timer(const Duration(seconds: 3), () async {
      _holdCtrl.stop();
      _ticker?.cancel();
      final streak = await ref
          .read(activeFocusProvider.notifier)
          .abandonSession();
      if (!mounted) return;
      ref.read(activeFocusProvider.notifier).reset();
      Navigator.of(context).pop();
      final c = AppColors.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            streak == 0
                ? 'Session ended. Streak has been reset.'
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
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdCtrl.reverse();
  }

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _motivationFor(int pct) {
    if (pct < 10) return _motivations[0];
    if (pct < 30) return _motivations[1];
    if (pct < 55) return _motivations[2];
    if (pct < 80) return _motivations[3];
    return _motivations[4];
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final session = ref.watch(activeFocusProvider);
    final stats = ref.watch(focusStatsProvider).valueOrNull;
    final pct = session.progressPercent;

    // Display names: strip package prefix if possible
    final displayNames = widget.blockedPackages.map((pkg) {
      final parts = pkg.split('.');
      return parts.length > 1 ? parts.last : pkg;
    }).toList();

    return Scaffold(
      backgroundColor: c.bg,
      // Back arrow works — returns to FocusPage, session keeps running
      appBar: AppBar(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: c.iconDefault,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: FadeTransition(
          opacity: _pulseCtrl.drive(Tween(begin: 0.5, end: 1.0)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Focus active',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.success,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'Streak: ${stats?.streak ?? 0} 🔥',
              style: TextStyle(fontSize: 13, color: c.subtitle),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // ── Ring timer ─────────────────────────────────────────
                  _RingTimer(
                    progress: session.progress,
                    label: _fmt(session.remainingSeconds),
                    percent: pct,
                  ),

                  const SizedBox(height: 24),

                  // ── Motivation ─────────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      key: ValueKey(_motivationFor(pct)),
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.success.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.success.withOpacity(0.2)),
                      ),
                      child: Text(
                        _motivationFor(pct),
                        style: TextStyle(
                          fontSize: 13,
                          color: c.success,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Blocked apps ───────────────────────────────────────
                  if (displayNames.isNotEmpty) ...[
                    Row(
                      children: [
                        Text(
                          'Blocked now',
                          style: TextStyle(fontSize: 12, color: c.subtitle),
                        ),
                        const Spacer(),
                        Text(
                          '${displayNames.length} apps',
                          style: TextStyle(fontSize: 12, color: c.subtitle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: displayNames.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.borderDefault),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: c.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                displayNames[i],
                                style: TextStyle(fontSize: 12, color: c.text),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Mini stats ─────────────────────────────────────────
                  Row(
                    children: [
                      _MiniStat(
                        value: '${stats?.streak ?? 0}',
                        label: 'Streak',
                        valueColor: c.success,
                      ),
                      const SizedBox(width: 10),
                      _MiniStat(
                        value: _fmtMin(stats?.todayMinutes ?? 0),
                        label: 'Today',
                        valueColor: c.text,
                      ),
                      const SizedBox(width: 10),
                      _MiniStat(
                        value: '${(stats?.completionRate ?? 0 * 100).round()}%',
                        label: 'Rate',
                        valueColor: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Info note ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.borderDefault),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Timer runs even if you go back. The bubble shows your remaining time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Session ends automatically when timer hits zero ✓',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Abandon button ───────────────────────────────────────────
            Positioned(
              left: 20,
              right: 20,
              bottom: 28,
              child: OutlinedButton(
                onPressed: () => setState(() => _showAbandon = true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.error,
                  side: BorderSide(color: c.error.withOpacity(0.4)),
                  backgroundColor: c.error.withOpacity(0.06),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Abandon session  (resets streak)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),

            // ── Hold-to-abandon sheet ────────────────────────────────────
            if (_showAbandon)
              _AbandonSheet(
                holdCtrl: _holdCtrl,
                onStartHold: _startHold,
                onCancelHold: _cancelHold,
                onDismiss: () {
                  _cancelHold();
                  setState(() => _showAbandon = false);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _fmtMin(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RING TIMER
// ─────────────────────────────────────────────────────────────────────────────
class _RingTimer extends StatelessWidget {
  final double progress;
  final String label;
  final int percent;

  const _RingTimer({
    required this.progress,
    required this.label,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 600),
            builder: (_, val, __) => CustomPaint(
              size: const Size(200, 200),
              painter: _RingPainter(
                progress: val,
                trackColor: c.borderDefault,
                progressColor: c.primary,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'remaining',
                style: TextStyle(fontSize: 13, color: c.subtitle),
              ),
              const SizedBox(height: 6),
              Text(
                '$percent% done',
                style: TextStyle(fontSize: 12, color: c.subtitle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 10;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// MINI STAT BOX
// ─────────────────────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _MiniStat({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.borderDefault),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: c.subtitle)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOLD-TO-ABANDON SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _AbandonSheet extends StatelessWidget {
  final AnimationController holdCtrl;
  final VoidCallback onStartHold;
  final VoidCallback onCancelHold;
  final VoidCallback onDismiss;

  const _AbandonSheet({
    required this.holdCtrl,
    required this.onStartHold,
    required this.onCancelHold,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: c.error.withOpacity(0.4)),
            left: BorderSide(color: c.error.withOpacity(0.4)),
            right: BorderSide(color: c.error.withOpacity(0.4)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠ This will break your streak',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.error,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hold "Abandon" for 3 seconds to confirm.',
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: holdCtrl,
              builder: (_, __) => ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: holdCtrl.value,
                  backgroundColor: c.borderDefault,
                  valueColor: AlwaysStoppedAnimation<Color>(c.error),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onLongPressStart: (_) => onStartHold(),
                    onLongPressEnd: (_) => onCancelHold(),
                    onLongPressCancel: onCancelHold,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Hold to abandon',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.borderDefault),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Keep going',
                        style: TextStyle(color: c.text, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLETION DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _CompletionDialog extends StatelessWidget {
  final int streak;
  final AppColorScheme colors;
  final VoidCallback onHome;

  const _CompletionDialog({
    required this.streak,
    required this.colors,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.borderDefault),
      ),
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
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '🔥 Streak: $streak days — kept!',
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to Focus',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
