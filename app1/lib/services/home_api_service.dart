import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/subject.dart';
import '../models/deck.dart';
import '../models/user_model.dart';

class HomeApiService {
  final Dio _dio = ApiClient.instance.dio;

  /// GET /api/user — fetch authenticated user info
  Future<UserModel> fetchUser() async {
    final res = await _dio.get('/user');
    return UserModel.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /api/subjects — fetch all subjects with chapter/document counts
  Future<List<Subject>> fetchSubjects() async {
    final res = await _dio.get('/subjects');
    final List data = res.data['data'] ?? res.data as List;
    return data
        .map((e) => Subject.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/subjects — create a subject
  Future<Subject> createSubject(String name) async {
    final res = await _dio.post('/subjects', data: {'name': name});
    return Subject.fromJson(
      res.data['data'] ?? res.data as Map<String, dynamic>,
    );
  }

  /// PUT /api/subjects/{id} — rename a subject
  Future<Subject> updateSubject(int id, String name) async {
    final res = await _dio.put('/subjects/$id', data: {'name': name});
    return Subject.fromJson(
      res.data['data'] ?? res.data as Map<String, dynamic>,
    );
  }

  /// DELETE /api/subjects/{id}
  Future<void> deleteSubject(int id) async {
    await _dio.delete('/subjects/$id');
  }

  /// GET /api/decks?limit=6 — fetch latest decks
  Future<List<Deck>> fetchRecentDecks({int limit = 6}) async {
    final res = await _dio.get('/decks', queryParameters: {'limit': limit});
    final List data = res.data['data'] ?? res.data as List;
    return data.map((e) => Deck.fromJson(e as Map<String, dynamic>)).toList();
  }
}
