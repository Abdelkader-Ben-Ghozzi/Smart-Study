import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course_details_models.dart';
import '../services/course_details_api_service.dart';
import '../services/local_cache_service.dart';

// ── Service ───────────────────────────────────────────────────────────────────
final courseDetailApiProvider = Provider<CourseDetailApiService>(
  (_) => CourseDetailApiService(),
);

// ── Sources ───────────────────────────────────────────────────────────────────
class SourcesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<CourseSource>, int> {
  @override
  Future<List<CourseSource>> build(int courseId) async {
    return _fetchWithFallback(courseId);
  }

  Future<List<CourseSource>> _fetchWithFallback(int courseId) async {
    try {
      final online = await ref
          .read(courseDetailApiProvider)
          .fetchSources(courseId);
      await LocalCacheService.saveSources(courseId, online);
      return online;
    } catch (_) {
      return LocalCacheService.loadSources(courseId);
    }
  }

  Future<Map<String, dynamic>> upload({
    required String filePath,
    required String fileName,
  }) async {
    final res = await ref
        .read(courseDetailApiProvider)
        .uploadSource(courseId: arg, filePath: filePath, fileName: fileName);
    if (res['success'] == true) ref.invalidateSelf();
    return res;
  }

  Future<void> delete(int sourceId) async {
    final current = state.value ?? [];
    state = AsyncData(current.where((s) => s.id != sourceId).toList());

    final ok = await ref
        .read(courseDetailApiProvider)
        .deleteSource(arg, sourceId);

    if (ok == false) {
      state = AsyncData(current);
    } else {
      await LocalCacheService.saveSources(arg, state.value ?? []);
    }
  }
}

final sourcesProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      SourcesNotifier,
      List<CourseSource>,
      int
    >(SourcesNotifier.new);

// ── AI Generation state ───────────────────────────────────────────────────────
enum GenerationStatus { idle, loading, done, error }

class GenerationState {
  final GenerationStatus status;
  final GeneratedContent? result;
  final String? error;

  const GenerationState({
    this.status = GenerationStatus.idle,
    this.result,
    this.error,
  });

  GenerationState copyWith({
    GenerationStatus? status,
    GeneratedContent? result,
    String? error,
  }) => GenerationState(
    status: status ?? this.status,
    result: result ?? this.result,
    error: error ?? this.error,
  );
}

// ── Generation Notifier ───────────────────────────────────────────────────────
class GenerationNotifier
    extends AutoDisposeFamilyNotifier<GenerationState, int> {
  @override
  GenerationState build(int courseId) => const GenerationState();

  Future<void> generate({
    required AiTool tool,
    int count = 10,
    String difficulty = 'medium',
    List<int> sourceIds = const [],
  }) async {
    // prevent multiple clicks
    if (state.status == GenerationStatus.loading) return;

    state = state.copyWith(status: GenerationStatus.loading, error: null);

    final res = await ref
        .read(courseDetailApiProvider)
        .generateAi(
          courseId: arg,
          tool: tool,
          count: count,
          difficulty: difficulty,
          sourceIds: sourceIds.isEmpty ? null : sourceIds,
        );

    if (res['success'] == true && res['data'] != null) {
      final generated = GeneratedContent.fromJson(
        res['data'] as Map<String, dynamic>,
      );

      await LocalCacheService.appendGeneratedContent(arg, generated);

      // ✅ update state FIRST
      state = state.copyWith(status: GenerationStatus.done, result: generated);

      // ✅ THEN refresh history (your requested fix)
      ref.refresh(aiHistoryProvider(arg));
    } else {
      state = state.copyWith(
        status: GenerationStatus.error,
        error: res['message'] as String? ?? 'Generation failed',
      );
    }
  }

  void reset() => state = const GenerationState();
}

final generationProvider =
    AutoDisposeNotifierProviderFamily<GenerationNotifier, GenerationState, int>(
      GenerationNotifier.new,
    );

// ── AI History ────────────────────────────────────────────────────────────────
final aiHistoryProvider = FutureProvider.autoDispose
    .family<List<GeneratedContent>, int>((ref, courseId) async {
      try {
        final online = await ref
            .read(courseDetailApiProvider)
            .fetchHistory(courseId);

        await LocalCacheService.saveGeneratedContent(courseId, online);
        return online;
      } catch (_) {
        return LocalCacheService.loadGeneratedContent(courseId);
      }
    });
