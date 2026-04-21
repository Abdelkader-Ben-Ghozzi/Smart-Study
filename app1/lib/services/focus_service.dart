// lib/services/focus_service.dart
// COMPLETE FILE — replaces previous version.
// startBlocking() takes a plain List<String> (positional, no named params).
// stopBlocking() takes no arguments.
// No updateBubbleTimer() — not needed; the Accessibility Service reads
// SharedPreferences directly.

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FocusService {
  static const _channel = MethodChannel('com.example.app1/focus');

  // ── Permissions ────────────────────────────────────────────────────────────

  static Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  static Future<bool> hasAccessibilityPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasAccessibilityPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestAccessibilityPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } catch (_) {}
  }

  // ── Session state (written to SharedPreferences so the service can read it) ──

  /// Activates the accessibility service blocker.
  static Future<void> startBlocking(List<String> blockedApps) async {
    print('startBlocking called with: $blockedApps');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session_active', true);
    await prefs.setString('blocked_apps', jsonEncode(blockedApps));
    print('SharedPrefs written: session_active=true, apps=$blockedApps');
  }

  /// Deactivates the blocker.
  static Future<void> stopBlocking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session_active', false);
    await prefs.setString('blocked_apps', '[]');
  }

  // ── Usage stats ────────────────────────────────────────────────────────────

  /// Returns a map of packageName → usage minutes for the past 24 h.
  static Future<Map<String, int>> getUsageStats() async {
    if (!Platform.isAndroid) return {};
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getUsageStats',
      );
      if (result == null) return {};
      return result.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  // ── Usage permission ───────────────────────────────────────────────────────

  static Future<bool> hasUsageStatsPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasUsageStatsPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestUsageStatsPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } catch (_) {}
  }
}
