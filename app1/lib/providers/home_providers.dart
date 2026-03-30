import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/home_api_service.dart';
import '../models/subject.dart';
import '../models/deck.dart';
import '../models/user_model.dart';

// ── Service provider ─────────────────────────────────────────────────────────
final homeApiServiceProvider = Provider<HomeApiService>(
  (_) => HomeApiService(),
);

// ── Theme mode provider ───────────────────────────────────────────────────────
// Uses Flutter's ThemeMode enum — pass directly to MaterialApp.themeMode.
// Toggle with: ref.read(themeModeProvider.notifier).state = ThemeMode.light
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.dark);

// ── User provider ─────────────────────────────────────────────────────────────
final userProvider = FutureProvider<UserModel>((ref) async {
  return ref.read(homeApiServiceProvider).fetchUser();
});

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

  void refresh() {
    ref.invalidateSelf();
  }
}

final subjectsProvider = AsyncNotifierProvider<SubjectsNotifier, List<Subject>>(
  SubjectsNotifier.new,
);

// ── Decks provider ────────────────────────────────────────────────────────────
final recentDecksProvider = FutureProvider<List<Deck>>((ref) async {
  return ref.read(homeApiServiceProvider).fetchRecentDecks();
});
