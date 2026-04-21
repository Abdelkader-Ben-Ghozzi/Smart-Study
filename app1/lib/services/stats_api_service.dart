// lib/services/stats_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StatsData {
  final Map<String, dynamic> courses;
  final Map<String, dynamic> sources;
  final Map<String, dynamic> ai;
  final Map<String, dynamic> social;
  final Map<String, dynamic> focus;
  final List<Map<String, dynamic>> activity;
  final List<Map<String, dynamic>> recentActivity;

  const StatsData({
    required this.courses,
    required this.sources,
    required this.ai,
    required this.social,
    required this.focus,
    required this.activity,
    required this.recentActivity,
  });

  factory StatsData.fromJson(Map<String, dynamic> json) {
    return StatsData(
      courses: Map<String, dynamic>.from(json['courses'] as Map),
      sources: Map<String, dynamic>.from(json['sources'] as Map),
      ai: Map<String, dynamic>.from(json['ai'] as Map),
      social: Map<String, dynamic>.from(json['social'] as Map),
      focus: json['focus'] != null
          ? Map<String, dynamic>.from(json['focus'] as Map)
          : {},
      activity: (json['activity'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      recentActivity: (json['recent_activity'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}

class StatsApiService {
  final String _base =
      'https://kasandra-unmeddled-heriberto.ngrok-free.dev/api';
  final _storage = const FlutterSecureStorage();

  Future<StatsData?> fetchStats() async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return null;
      final res = await http.get(
        Uri.parse('$_base/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return StatsData.fromJson(body['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
