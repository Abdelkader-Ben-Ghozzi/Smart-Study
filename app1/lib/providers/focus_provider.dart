// lib/providers/focus_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/focus_session.dart';
import '../services/focus_api_service.dart';
import '../services/focus_service.dart';

// ── Service ────────────────────────────────────────────────────────────────
final focusApiServiceProvider = Provider<FocusApiService>(
  (_) => FocusApiService(),
);

// ── Settings ───────────────────────────────────────────────────────────────
class FocusSettingsNotifier extends AsyncNotifier<FocusSettings> {
  static const _key = 'focus_settings_v3';

  @override
  Future<FocusSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const FocusSettings();
    try {
      return FocusSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const FocusSettings();
    }
  }

  Future<void> save(FocusSettings settings) async {
    state = AsyncData(settings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}

final focusSettingsProvider =
    AsyncNotifierProvider<FocusSettingsNotifier, FocusSettings>(
      FocusSettingsNotifier.new,
    );

// ── Active session state ───────────────────────────────────────────────────
enum FocusPhase { idle, active, completed, abandoned }

class ActiveFocusState {
  final FocusPhase phase;
  final int? sessionId;
  final int totalSeconds;
  final int remainingSeconds;
  final List<String> blockedPackages;

  const ActiveFocusState({
    this.phase = FocusPhase.idle,
    this.sessionId,
    this.totalSeconds = 0,
    this.remainingSeconds = 0,
    this.blockedPackages = const [],
  });

  double get progress =>
      totalSeconds == 0 ? 0 : 1 - (remainingSeconds / totalSeconds);
  int get progressPercent => (progress * 100).round();

  ActiveFocusState copyWith({
    FocusPhase? phase,
    int? sessionId,
    int? totalSeconds,
    int? remainingSeconds,
    List<String>? blockedPackages,
  }) => ActiveFocusState(
    phase: phase ?? this.phase,
    sessionId: sessionId ?? this.sessionId,
    totalSeconds: totalSeconds ?? this.totalSeconds,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    blockedPackages: blockedPackages ?? this.blockedPackages,
  );
}

// ── Active session notifier ────────────────────────────────────────────────
class ActiveFocusNotifier extends Notifier<ActiveFocusState> {
  @override
  ActiveFocusState build() => const ActiveFocusState();

  Future<bool> startSession(
    int durationMinutes,
    List<String> blockedPackages,
  ) async {
    // 1. Clean up any existing session first
    if (state.phase == FocusPhase.active) {
      await FocusService.stopBlocking();
      if (state.sessionId != null) {
        await ref
            .read(focusApiServiceProvider)
            .abandonSession(state.sessionId!);
      }
    }

    // 2. Call API
    final result = await ref
        .read(focusApiServiceProvider)
        .startSession(durationMinutes);

    if (result['success'] == true) {
      final sessionData = result['session'] as Map<String, dynamic>;
      final totalSecs = durationMinutes * 60;

      // 3. Update Flutter state
      state = ActiveFocusState(
        phase: FocusPhase.active,
        sessionId: sessionData['id'] as int,
        totalSeconds: totalSecs,
        remainingSeconds: totalSecs,
        blockedPackages: blockedPackages,
      );

      // 4. Start native blocker (positional args — matches FocusService)
      await FocusService.startBlocking(blockedPackages);

      return true;
    }
    return false;
  }

  /// Called every second by the ticker in FocusPage / ActiveFocusScreen.
  void tick() {
    if (state.phase != FocusPhase.active) return;
    if (state.remainingSeconds <= 0) return;

    final newRemaining = state.remainingSeconds - 1;
    state = state.copyWith(remainingSeconds: newRemaining);
    // No bubble update needed — bubble reads SharedPreferences directly
    // via the Accessibility Service, not a separate method call.
  }

  Future<int> completeSession() async {
    if (state.sessionId == null) return 0;

    await FocusService.stopBlocking();

    final result = await ref
        .read(focusApiServiceProvider)
        .completeSession(state.sessionId!);

    state = state.copyWith(phase: FocusPhase.completed);
    ref.invalidate(focusStatsProvider);
    return result['streak'] as int? ?? 0;
  }

  Future<int> abandonSession() async {
    if (state.sessionId == null) return 0;

    await FocusService.stopBlocking();

    final result = await ref
        .read(focusApiServiceProvider)
        .abandonSession(state.sessionId!);

    state = const ActiveFocusState(phase: FocusPhase.abandoned);
    ref.invalidate(focusStatsProvider);
    return result['streak'] as int? ?? 0;
  }

  void reset() => state = const ActiveFocusState();
}

final activeFocusProvider =
    NotifierProvider<ActiveFocusNotifier, ActiveFocusState>(
      ActiveFocusNotifier.new,
    );

// ── Stats ──────────────────────────────────────────────────────────────────
class FocusStatsNotifier extends AsyncNotifier<FocusStats> {
  @override
  Future<FocusStats> build() async {
    ref.keepAlive();
    return ref.read(focusApiServiceProvider).fetchStats();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(focusApiServiceProvider).fetchStats(),
    );
  }
}

final focusStatsProvider =
    AsyncNotifierProvider<FocusStatsNotifier, FocusStats>(
      FocusStatsNotifier.new,
    );
