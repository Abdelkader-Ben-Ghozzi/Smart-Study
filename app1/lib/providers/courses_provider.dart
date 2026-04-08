import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../services/course_api_service.dart';

final courseApiServiceProvider = Provider<CourseApiService>(
  (_) => CourseApiService(),
);

final courseTabProvider = StateProvider<CourseTab>((_) => CourseTab.all);
final courseSortProvider = StateProvider<CourseSort>((_) => CourseSort.recent);
final courseSearchProvider = StateProvider<String>((_) => '');

class CoursesNotifier extends AsyncNotifier<List<Course>> {
  @override
  Future<List<Course>> build() async {
    ref.keepAlive();

    final tab = ref.watch(courseTabProvider);
    final sort = ref.watch(courseSortProvider);
    final search = ref.watch(courseSearchProvider);

    return ref
        .read(courseApiServiceProvider)
        .fetchCourses(tab: tab, sort: sort, search: search);
  }

  void refresh() => ref.invalidateSelf();

  Future<void> toggleFavorite(int id) async {
    final current = state.value ?? [];
    state = AsyncData(
      current
          .map((c) => c.id == id ? c.copyWith(isFavorite: !c.isFavorite) : c)
          .toList(),
    );
    final res = await ref.read(courseApiServiceProvider).toggleFavorite(id);
    if (res['success'] != true) state = AsyncData(current);
  }

  Future<void> toggleSave(int id) async {
    final current = state.value ?? [];
    state = AsyncData(
      current
          .map((c) => c.id == id ? c.copyWith(isSaved: !c.isSaved) : c)
          .toList(),
    );
    final res = await ref.read(courseApiServiceProvider).toggleSave(id);
    if (res['success'] != true) state = AsyncData(current);
  }

  Future<Map<String, dynamic>> create({
    required String title,
    String? description,
    String? color,
    String? icon,
    String visibility = 'private',
  }) async {
    final res = await ref
        .read(courseApiServiceProvider)
        .createCourse(
          title: title,
          description: description,
          color: color,
          icon: icon,
          visibility: visibility,
        );
    if (res['success'] == true) ref.invalidateSelf();
    return res;
  }

  Future<Map<String, dynamic>> rename(
    int id,
    String newTitle, {
    String? visibility,
  }) async {
    final res = await ref
        .read(courseApiServiceProvider)
        .updateCourse(id, title: newTitle, visibility: visibility);
    if (res['success'] == true) ref.invalidateSelf();
    return res;
  }

  Future<Map<String, dynamic>> delete(int id) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((c) => c.id != id).toList());
    final res = await ref.read(courseApiServiceProvider).deleteCourse(id);
    if (res['success'] != true) state = AsyncData(current);
    return res;
  }
}

final coursesProvider = AsyncNotifierProvider<CoursesNotifier, List<Course>>(
  CoursesNotifier.new,
);
