import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../reading/data/reading_session_repository_provider.dart';

/// 週間読書時間（直近7日間・分）を提供するProvider
final weeklyReadingMinutesProvider = FutureProvider<List<int>>((ref) {
  final repo = ref.watch(readingSessionRepositoryProvider);
  return repo.getWeeklyReadingMinutes();
});
