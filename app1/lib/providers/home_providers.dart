import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/home_api_service.dart';
import '../models/subject.dart';
import '../models/deck.dart';
import '../models/user_model.dart';

// ── Service provider ──────────────────────────────────────────────────────────
final homeApiServiceProvider = Provider<HomeApiService>(
  (_) => HomeApiService(),
);

// ── Theme mode ────────────────────────────────────────────────────────────────
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.dark);

// ── User provider — AsyncNotifier so invalidate() triggers a real re-fetch ────
class UserNotifier extends AsyncNotifier<UserModel> {
  @override
  Future<UserModel> build() async {
    return ref.read(homeApiServiceProvider).fetchUser();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(homeApiServiceProvider).fetchUser(),
    );
  }
}

final userProvider = AsyncNotifierProvider<UserNotifier, UserModel>(
  UserNotifier.new,
);

// ── Subjects notifier ─────────────────────────────────────────────────────────
class SubjectsNotifier extends AsyncNotifier<List<Subject>> {
  @override
  Future<List<Subject>> build() async {
    return ref.read(homeApiServiceProvider).fetchSubjects();
  }

  Future<void> add(String name) async {
    final svc = ref.read(homeApiServiceProvider);
    final created = await svc.createSubject(name);
    state = AsyncData([...state.value ?? [], created]);
  }

  Future<void> rename(int id, String newName) async {
    final svc = ref.read(homeApiServiceProvider);
    final updated = await svc.updateSubject(id, newName);
    state = AsyncData(
      (state.value ?? []).map((s) => s.id == id ? updated : s).toList(),
    );
  }

  Future<void> remove(int id) async {
    final svc = ref.read(homeApiServiceProvider);
    await svc.deleteSubject(id);
    state = AsyncData((state.value ?? []).where((s) => s.id != id).toList());
  }

  void refresh() => ref.invalidateSelf();
}

final subjectsProvider = AsyncNotifierProvider<SubjectsNotifier, List<Subject>>(
  SubjectsNotifier.new,
);

// ── Decks provider ─────────────────────────────────────────────────────────────
final recentDecksProvider = FutureProvider<List<Deck>>((ref) async {
  return ref.read(homeApiServiceProvider).fetchRecentDecks();
});
