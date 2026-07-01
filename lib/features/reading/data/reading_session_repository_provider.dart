import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/infrastructure/hive/box_manager_provider.dart';
import '../../../domain/repositories/reading_session_repository.dart';
import 'hive_reading_session_repository.dart';

/// ReadingSessionRepository の Riverpod Provider
/// Hive をプライマリデータストアとして使用する（Offline-First）
final readingSessionRepositoryProvider =
    Provider<ReadingSessionRepository>((ref) {
  final boxManager = ref.watch(hiveBoxManagerProvider);
  return HiveReadingSessionRepository(boxManager);
});
