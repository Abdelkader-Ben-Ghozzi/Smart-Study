import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/course_details_models.dart';

class CourseDetailApiService {
  final String _base;
  final FlutterSecureStorage _storage;

  CourseDetailApiService({
    String baseUrl = 'https://kasandra-unmeddled-heriberto.ngrok-free.dev/api',
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _base = baseUrl,
       _storage = storage;

  Future<String?> _token() => _storage.read(key: 'token');

  Map<String, String> _auth(String t) => {
    'Authorization': 'Bearer $t',
    'Accept': 'application/json',
  };

  // ── GET /api/courses/{courseId}/sources ───────────────────────────────────
  Future<List<CourseSource>> fetchSources(int courseId) async {
    try {
      final token = await _token();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('$_base/courses/$courseId/sources'),
        headers: _auth(token),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['data'] as List? ?? [];
        return list
            .map((e) => CourseSource.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── POST /api/courses/{courseId}/sources — multipart upload ───────────────
  Future<Map<String, dynamic>> uploadSource({
    required int courseId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      final token = await _token();
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_base/courses/$courseId/sources'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields['name'] = fileName;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 201) return {'success': true, ...body};
      return {'success': false, 'message': body['message'] ?? 'Upload failed'};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ── DELETE /api/courses/{courseId}/sources/{id} ───────────────────────────
  Future<Map<String, dynamic>> deleteSource(int courseId, int sourceId) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false};
      final res = await http.delete(
        Uri.parse('$_base/courses/$courseId/sources/$sourceId'),
        headers: _auth(token),
      );
      if (res.statusCode == 200 || res.statusCode == 204)
        return {'success': true};
      return {'success': false, 'message': 'Delete failed'};
    } on SocketException {
      return {'success': false, 'message': 'No internet'};
    } catch (_) {
      return {'success': false, 'message': 'Error'};
    }
  }

  // ── POST /api/courses/{courseId}/ai/generate ──────────────────────────────
  Future<Map<String, dynamic>> generateAi({
    required int courseId,
    required AiTool tool,
    int count = 10,
    String difficulty = 'medium',
    List<int>? sourceIds,
  }) async {
    try {
      final token = await _token();
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};

      final body = <String, dynamic>{
        'tool': tool.name,
        'count': count,
        'difficulty': difficulty,
        if (sourceIds != null && sourceIds.isNotEmpty) 'source_ids': sourceIds,
      };

      final res = await http.post(
        Uri.parse('$_base/courses/$courseId/ai/generate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...decoded};

      return {
        'success': false,
        'message': decoded['message'] ?? 'Generation failed',
      };
    } on SocketException {
      return {'success': false, 'message': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ── GET /api/courses/{courseId}/ai/history ────────────────────────────────
  Future<List<GeneratedContent>> fetchHistory(int courseId) async {
    try {
      final token = await _token();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('$_base/courses/$courseId/ai/history'),
        headers: _auth(token),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['data'] as List? ?? [];
        return list
            .map((e) => GeneratedContent.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── DELETE /api/courses/{courseId}/ai/{contentId} ─────────────────────────
  Future<bool> deleteGeneratedContent(int courseId, int contentId) async {
    try {
      final token = await _token();
      if (token == null) return false;
      final res = await http.delete(
        Uri.parse('$_base/courses/$courseId/ai/$contentId'),
        headers: _auth(token),
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
