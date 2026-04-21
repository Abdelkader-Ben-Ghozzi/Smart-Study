// lib/services/focus_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/focus_session.dart';

class FocusApiService {
  static const String _base =
      'https://kasandra-unmeddled-heriberto.ngrok-free.dev/api';

  final _storage = const FlutterSecureStorage();

  Map<String, String> get _baseHeaders => const {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'token');
    return {..._baseHeaders, 'Authorization': 'Bearer $token'};
  }

  // POST /focus/sessions — start a new session
  Future<Map<String, dynamic>> startSession(int durationMinutes) async {
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$_base/focus/sessions'),
      headers: headers,
      body: jsonEncode({'duration_minutes': durationMinutes}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) {
      return {'success': true, 'session': body['session']};
    }
    return {'success': false, 'message': body['message'] ?? 'Failed to start'};
  }

  // PUT /focus/sessions/{id}/complete — timer hit zero
  Future<Map<String, dynamic>> completeSession(int sessionId) async {
    final headers = await _authHeaders();
    final res = await http.put(
      Uri.parse('$_base/focus/sessions/$sessionId/complete'),
      headers: headers,
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      return {'success': true, 'streak': body['streak']};
    }
    return {
      'success': false,
      'message': body['message'] ?? 'Failed to complete',
    };
  }

  // PUT /focus/sessions/{id}/abandon — user held the button
  Future<Map<String, dynamic>> abandonSession(int sessionId) async {
    final headers = await _authHeaders();
    final res = await http.put(
      Uri.parse('$_base/focus/sessions/$sessionId/abandon'),
      headers: headers,
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      return {'success': true, 'streak': body['streak']};
    }
    return {
      'success': false,
      'message': body['message'] ?? 'Failed to abandon',
    };
  }

  // GET /focus/stats
  Future<FocusStats> fetchStats() async {
    final headers = await _authHeaders();
    final res = await http.get(
      Uri.parse('$_base/focus/stats'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      return FocusStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load focus stats: ${res.statusCode}');
  }
}
