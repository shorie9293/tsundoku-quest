import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/reading_session.dart';
import '../../reading/data/reading_session_repository_provider.dart';

/// 全読書セッション（読書習慣ヒートマップ集計用・直近5000件）
final readingHabitSessionsProvider = FutureProvider<List<ReadingSession>>((ref) {
  final repo = ref.watch(readingSessionRepositoryProvider);
  return repo.getRecentSessions(limit: 5000);
});