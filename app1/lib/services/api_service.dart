import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final String baseUrl = 'http://127.0.0.1:8000/api';
  final storage = const FlutterSecureStorage();

  // ── Register ──────────────────────────────────────────────────────────────
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
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          'password': password,
          'password_confirmation': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (data['token'] != null) {
          await storage.write(key: 'token', value: data['token']);
        }
        return {'success': true, ...data};
      }

      if (data['errors'] != null) {
        final errors = data['errors'] as Map<String, dynamic>;
        if (errors.containsKey('email')) {
          return {
            'success': false,
            'message': 'This email is already registered',
          };
        }
        if (errors.containsKey('phone')) {
          return {
            'success': false,
            'message': 'This phone number is already registered',
          };
        }
        final firstError = (errors.values.first as List).first.toString();
        return {'success': false, 'message': firstError};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error, please try again'};
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['token'] != null) {
          await storage.write(key: 'token', value: data['token']);
        }
        return {'success': true, ...data};
      }

      if (data['errors'] != null) {
        final errors = data['errors'] as Map<String, dynamic>;
        final firstError = (errors.values.first as List).first.toString();
        return {'success': false, 'message': firstError};
      }

      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } on SocketException {
      return {'success': false, 'message': 'No internet connection'};
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Something went wrong: $e'};
    }
  }

  // ── Check email exists ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> checkEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password/check-email'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return {'success': true, ...data};
      return {
        'success': false,
        'message': data['message'] ?? 'Email not found',
      };
    } on SocketException {
      return {'success': false, 'message': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ── Send OTP ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> sendOtp(String email, String method) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'method': method}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return {'success': true, ...data};
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to send OTP',
      };
    } on SocketException {
      return {'success': false, 'message': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'otp': otp}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return {'success': true, ...data};
      return {
        'success': false,
        'message': data['message'] ?? 'Invalid OTP',
        'expired': data['expired'] ?? false,
        'locked': data['locked'] ?? false,
        'remaining': data['remaining'] ?? 0,
      };
    } on SocketException {
      return {'success': false, 'message': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ── Reset Password ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String resetToken,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password/reset'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'reset_token': resetToken,
          'password': password,
          'password_confirmation': password,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': data['message'] ?? 'Reset failed'};
    } on SocketException {
      return {'success': false, 'message': 'No internet connection'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<String?> getToken() async => await storage.read(key: 'token');
  Future<void> logout() async => await storage.delete(key: 'token');
  Future<bool> isLoggedIn() async {
    final token = await storage.read(key: 'token');
    return token != null && token.isNotEmpty;
  }
}
