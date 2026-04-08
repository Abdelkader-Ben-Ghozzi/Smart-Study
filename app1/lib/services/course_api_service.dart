import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/course.dart';

class CourseApiService {
  final String _base;
  final FlutterSecureStorage _storage;

  CourseApiService({
    String baseUrl = 'https://kasandra-unmeddled-heriberto.ngrok-free.dev/api',
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _base = baseUrl,
       _storage = storage;

  Future<String?> _token() => _storage.read(key: 'token');

  Map<String, String> _auth(String t) => {
    'Authorization': 'Bearer $t',
    'Accept': 'application/json',
  };

  Map<String, String> _json(String t) => {
    'Authorization': 'Bearer $t',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── GET /api/courses ──────────────────────────────────────────────────────
  Future<List<Course>> fetchCourses({
    CourseTab tab = CourseTab.all,
    CourseSort sort = CourseSort.recent,
    String search = '',
  }) async {
    try {
      final token = await _token();
      if (token == null) return [];

      final tabStr = tab.name;
      final sortStr = switch (sort) {
        CourseSort.recent => 'recent',
        CourseSort.favorite => 'fav',
        CourseSort.alpha => 'alpha',
      };

      final uri = Uri.parse('$_base/courses').replace(
        queryParameters: {
          'tab': tabStr,
          'sort': sortStr,
          if (search.isNotEmpty) 'search': search,
        },
      );

      final res = await http.get(uri, headers: _auth(token));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['data'] as List? ?? [];

        List<Course> courses = list
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList();

        if (sort == CourseSort.alpha) {
          courses.sort((a, b) {
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
        }

        return courses;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── POST /api/courses ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createCourse({
    required String title,
    String? description,
    String? color,
    String? icon,
    String visibility = 'private',
  }) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final res = await http.post(
        Uri.parse('$_base/courses'),
        headers: _json(token),
        body: jsonEncode({
          'title': title,
          'description': ?description,
          'color': ?color,
          'icon': ?icon,
          'visibility': visibility,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 201) return {'success': true, ...body};
      return {
        'success': false,
        'message': body['message'] ?? 'Failed to create',
      };
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ── PUT /api/courses/{id} ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> updateCourse(
    int id, {
    String? title,
    String? description,
    String? color,
    String? icon,
    String? visibility,
  }) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final res = await http.put(
        Uri.parse('$_base/courses/$id'),
        headers: _json(token),
        body: jsonEncode({
          'title': ?title,
          'description': ?description,
          'color': ?color,
          'icon': ?icon,
          'visibility': ?visibility,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...body};
      return {
        'success': false,
        'message': body['message'] ?? 'Failed to update',
      };
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ── DELETE /api/courses/{id} ──────────────────────────────────────────────
  Future<Map<String, dynamic>> deleteCourse(int id) async {
    try {
      final token = await _token();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final res = await http.delete(
        Uri.parse('$_base/courses/$id'),
        headers: _auth(token),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        return {'success': true};
      }
      final body = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};
      return {'success': false, 'message': body['message'] ?? 'Failed'};
    } on SocketException {
      return {'success': false, 'message': 'No internet connection'};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ── POST /api/courses/{id}/favorite ──────────────────────────────────────
  Future<Map<String, dynamic>> toggleFavorite(int id) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false};
      final res = await http.post(
        Uri.parse('$_base/courses/$id/favorite'),
        headers: _auth(token),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...body};
      return {'success': false};
    } catch (_) {
      return {'success': false};
    }
  }

  // ── POST /api/courses/{id}/save ───────────────────────────────────────────
  Future<Map<String, dynamic>> toggleSave(int id) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false};
      final res = await http.post(
        Uri.parse('$_base/courses/$id/save'),
        headers: _auth(token),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...body};
      return {'success': false, 'message': body['message']};
    } catch (_) {
      return {'success': false};
    }
  }
}
