import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/stats_api_service.dart';

final statsApiServiceProvider = Provider<StatsApiService>(
  (_) => StatsApiService(),
);

final statsProvider = FutureProvider<StatsData?>((ref) async {
  return ref.read(statsApiServiceProvider).fetchStats();
});
