// lib/models/focus_session.dart

class FocusSettings {
  final int durationMinutes;
  final List<String> blockedApps;

  const FocusSettings({this.durationMinutes = 50, this.blockedApps = const []});

  FocusSettings copyWith({int? durationMinutes, List<String>? blockedApps}) =>
      FocusSettings(
        durationMinutes: durationMinutes ?? this.durationMinutes,
        blockedApps: blockedApps ?? this.blockedApps,
      );

  Map<String, dynamic> toJson() => {
    'duration_minutes': durationMinutes,
    'blocked_apps': blockedApps,
  };

  factory FocusSettings.fromJson(Map<String, dynamic> json) => FocusSettings(
    durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 50,
    blockedApps:
        (json['blocked_apps'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
  );
}

class FocusStats {
  final int streak;
  final int todayMinutes;
  final int weekMinutes;
  final double completionRate;
  final int totalSessions;
  final int bestStreak;

  const FocusStats({
    this.streak = 0,
    this.todayMinutes = 0,
    this.weekMinutes = 0,
    this.completionRate = 0,
    this.totalSessions = 0,
    this.bestStreak = 0,
  });

  factory FocusStats.fromJson(Map<String, dynamic> json) => FocusStats(
    streak: (json['streak'] as num?)?.toInt() ?? 0,
    todayMinutes: (json['today_minutes'] as num?)?.toInt() ?? 0,
    weekMinutes: (json['week_minutes'] as num?)?.toInt() ?? 0,
    completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
    totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
    bestStreak: (json['best_streak'] as num?)?.toInt() ?? 0,
  );
}
