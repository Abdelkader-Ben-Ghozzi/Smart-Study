import 'package:flutter/material.dart';

class AppColorScheme {
  final Color bg;
  final Color surface;
  final Color surfaceElevated;
  final Color fieldBg;
  final Color fieldBgFocus;
  final Color borderDefault;
  final Color borderFocus;
  final Color borderError;
  final Color iconDefault;
  final Color iconFocus;
  final Color hint;
  final Color text;
  final Color textSecondary;
  final Color subtitle;
  final Color primary;
  final Color primaryLight;
  final Color success;
  final Color error;
  final Color divider;
  final Color cardBg;
  final Color cardBorder;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const AppColorScheme({
    required this.bg,
    required this.surface,
    required this.surfaceElevated,
    required this.fieldBg,
    required this.fieldBgFocus,
    required this.borderDefault,
    required this.borderFocus,
    required this.borderError,
    required this.iconDefault,
    required this.iconFocus,
    required this.hint,
    required this.text,
    required this.textSecondary,
    required this.subtitle,
    required this.primary,
    required this.primaryLight,
    required this.success,
    required this.error,
    required this.divider,
    required this.cardBg,
    required this.cardBorder,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  static const dark = AppColorScheme(
    bg: Color.fromARGB(255, 18, 20, 24),
    surface: Color(0xFF1C1F2E),
    surfaceElevated: Color(0xFF20243A),
    fieldBg: Color(0xFF1C1F2E),
    fieldBgFocus: Color(0xFF20243A),
    borderDefault: Color(0xFF2A2F4A),
    borderFocus: Color(0xFF3055E7),
    borderError: Color(0xFFE53935),
    iconDefault: Color(0xFF4A5272),
    iconFocus: Color(0xFF3055E7),
    hint: Color(0xFF3E4460),
    text: Color(0xFFCDD5F0),
    textSecondary: Color(0xFF8A93B8),
    subtitle: Color(0xFF4A5272),
    primary: Color(0xFF3055E7),
    primaryLight: Color(0xFF4A6EFF),
    success: Color(0xFF2E7D32),
    error: Color(0xFFE53935),
    divider: Color(0xFF1E2130),
    cardBg: Color(0xFF1C1F2E),
    cardBorder: Color(0xFF2A2F4A),
    shimmerBase: Color(0xFF1C1F2E),
    shimmerHighlight: Color(0xFF252840),
  );

  static const light = AppColorScheme(
    bg: Color.fromARGB(255, 216, 216, 217),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF0F2FA),
    fieldBg: Color(0xFFF0F2FA),
    fieldBgFocus: Color(0xFFE8ECF8),
    borderDefault: Color(0xFFD0D6EC),
    borderFocus: Color(0xFF3055E7),
    borderError: Color(0xFFE53935),
    iconDefault: Color(0xFF8A93B8),
    iconFocus: Color(0xFF3055E7),
    hint: Color(0xFFB0B8D4),
    text: Color(0xFF1A1D2E),
    textSecondary: Color(0xFF4A5272),
    subtitle: Color(0xFF6B75A0),
    primary: Color(0xFF3055E7),
    primaryLight: Color(0xFF4A6EFF),
    success: Color(0xFF2E7D32),
    error: Color(0xFFE53935),
    divider: Color(0xFFE4E8F4),
    cardBg: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE0E5F5),
    shimmerBase: Color(0xFFEEF0FA),
    shimmerHighlight: Color(0xFFF8F9FE),
  );
}

/// Inherited widget to provide color scheme down the tree.
class AppColors extends InheritedWidget {
  final AppColorScheme scheme;

  const AppColors({super.key, required this.scheme, required super.child});

  static AppColorScheme of(BuildContext context) {
    final AppColors? result = context
        .dependOnInheritedWidgetOfExactType<AppColors>();
    return result?.scheme ?? AppColorScheme.dark;
  }

  @override
  bool updateShouldNotify(AppColors oldWidget) => scheme != oldWidget.scheme;
}
