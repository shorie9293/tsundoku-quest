import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'hive_reading_session_repository.dart';

/// ReadingSessionRepository の Riverpod Provider
/// Hive ローカル永続化をプライマリ、Supabase はバックグラウンド同期（別途）
final readingSessionRepositoryProvider =
    Provider<ReadingSessionRepository>((ref) {
  final boxManager = ref.watch(hiveBoxManagerProvider);
  return HiveReadingSessionRepository(boxManager);
});
