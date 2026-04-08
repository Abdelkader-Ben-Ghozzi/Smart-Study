import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final String baseUrl =
      'https://kasandra-unmeddled-heriberto.ngrok-free.dev/api';
  final storage = const FlutterSecureStorage();

  // ── Headers ───────────────────────────────────────────────────────────────

  // Added ngrok-skip-browser-warning to prevent the 404/502 landing page issues
  Map<String, String> get _baseHeaders => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  Map<String, String> _authHeaders(String token) => {
    ..._baseHeaders,
    'Authorization': 'Bearer $token',
  };

  Map<String, String> _jsonHeaders(String token) => {
    ..._baseHeaders,
    'Authorization': 'Bearer $token',
  };

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> getToken() async => storage.read(key: 'token');

  Future<bool> isLoggedIn() async {
    final token = await storage.read(key: 'token');
    return token != null && token.isNotEmpty;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (!RegExp(r'^[2459]\d{7}$').hasMatch(phone)) {
      return {'success': false, 'message': 'Invalid phone number format'};
    }
    if (!RegExp(
      r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[-*?@]).{8,}$',
    ).hasMatch(password)) {
      return {
        'success': false,
        'message': 'Password does not meet requirements',
      };
    }
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: _baseHeaders,
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          'password': password,
          'password_confirmation': password,
        }),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (data['token'] != null) {
          await storage.write(key: 'token', value: data['token'] as String);
        }
        return {'success': true, ...data};
      }
      if (data['errors'] != null) {
        final errors = data['errors'] as Map<String, dynamic>;
        if (errors.containsKey('email'))
          return {
            'success': false,
            'message': 'This email is already registered',
          };
        if (errors.containsKey('phone'))
          return {
            'success': false,
            'message': 'This phone number is already registered',
          };
        return {
          'success': false,
          'message': (errors.values.first as List).first.toString(),
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed',
      };
    } catch (_) {
      return {'success': false, 'message': 'Network error, please try again'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: _baseHeaders,
        body: jsonEncode({'email': email, 'password': password}),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        if (data['token'] != null) {
          await storage.write(key: 'token', value: data['token'] as String);
        }
        return {'success': true, ...data};
      }
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } on SocketException {
      return {'success': false, 'message': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'message': 'Something went wrong'};
    }
  }

  Future<Map<String, dynamic>> logout() async {
    try {
      final token = await storage.read(key: 'token');
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: _authHeaders(token),
        );
      }
    } finally {
      await storage.deleteAll();
    }
    return {'success': true};
  }

  // ── Forgot Password ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> checkEmail(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/forgot-password/check-email'),
        headers: _baseHeaders,
        body: jsonEncode({'email': email}),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...data};
      return {
        'success': false,
        'message': data['message'] ?? 'Email not found',
      };
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> sendOtp(String email, String method) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/forgot-password/send-otp'),
        headers: _baseHeaders,
        body: jsonEncode({'email': email, 'method': method}),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...data};
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to send OTP',
      };
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/forgot-password/verify-otp'),
        headers: _baseHeaders,
        body: jsonEncode({'email': email, 'otp': otp}),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...data};
      return {'success': false, ...data};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String resetToken,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/forgot-password/reset'),
        headers: _baseHeaders,
        body: jsonEncode({
          'email': email,
          'reset_token': resetToken,
          'password': password,
          'password_confirmation': password,
        }),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': data['message'] ?? 'Reset failed'};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};
      final res = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: _authHeaders(token),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': 'Failed to load profile'};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    String? phone,
  }) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};
      final res = await http.put(
        Uri.parse('$baseUrl/user/profile'),
        headers: _jsonHeaders(token),
        body: jsonEncode({'name': name, 'email': email, 'phone': phone}),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': data['message'] ?? 'Update failed'};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> uploadAvatar({required String filePath}) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/user/avatar'),
      );
      request.headers.addAll(_authHeaders(token)); // Includes ngrok bypass
      request.files.add(await http.MultipartFile.fromPath('avatar', filePath));
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': data['message'] ?? 'Upload failed'};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};
      final res = await http.put(
        Uri.parse('$baseUrl/user/password'),
        headers: _jsonHeaders(token),
        body: jsonEncode({
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': newPassword,
        }),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': data['message'] ?? 'Failed'};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ── Documents ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDocuments() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};
      final res = await http.get(
        Uri.parse('$baseUrl/documents'),
        headers: _authHeaders(token),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': 'Failed to load documents'};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> uploadPdf({
    required String filePath,
    required String name,
    int? subjectId,
  }) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/documents'),
      );
      request.headers.addAll(_authHeaders(token));
      request.fields['name'] = name;
      if (subjectId != null)
        request.fields['subject_id'] = subjectId.toString();
      request.files.add(await http.MultipartFile.fromPath('pdf', filePath));
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 201) return {'success': true, ...data};
      return {'success': false, 'message': data['message'] ?? 'Upload failed'};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> deleteDocument(int id) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};
      final res = await http.delete(
        Uri.parse('$baseUrl/documents/$id'),
        headers: _authHeaders(token),
      );
      if (res.statusCode == 200 || res.statusCode == 204)
        return {'success': true};
      final data = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : {};
      return {'success': false, 'message': data['message'] ?? 'Delete failed'};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ── Subjects ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSubjects() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};
      final res = await http.get(
        Uri.parse('$baseUrl/subjects'),
        headers: _authHeaders(token),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': 'Failed to load subjects'};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> createSubject(String name) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};
      final res = await http.post(
        Uri.parse('$baseUrl/subjects'),
        headers: _jsonHeaders(token),
        body: jsonEncode({'name': name}),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 201) return {'success': true, ...data};
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to create',
      };
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> updateSubject(int id, String name) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};
      final res = await http.put(
        Uri.parse('$baseUrl/subjects/$id'),
        headers: _jsonHeaders(token),
        body: jsonEncode({'name': name}),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...data};
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update',
      };
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>> deleteSubject(int id) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};
      final res = await http.delete(
        Uri.parse('$baseUrl/subjects/$id'),
        headers: _authHeaders(token),
      );
      if (res.statusCode == 200 || res.statusCode == 204)
        return {'success': true};
      final data = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : {};
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to delete',
      };
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ── Decks ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDecks({int? limit}) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null)
        return {'success': false, 'message': 'Not authenticated'};
      final uri = Uri.parse(
        '$baseUrl/decks',
      ).replace(queryParameters: limit != null ? {'limit': '$limit'} : null);
      final res = await http.get(uri, headers: _authHeaders(token));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': 'Failed to load decks'};
    } catch (_) {
      return {'success': false, 'message': 'Network error'};
    }
  }
}
