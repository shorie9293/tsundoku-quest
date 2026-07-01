/// Riverpod provider for HiveReadingSessionRepository
///
/// Provides a ReadingSessionRepository backed by Hive local persistence.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'hive_reading_session_repository.dart';

/// Hive-based ReadingSessionRepository provider
final hiveReadingSessionRepositoryProvider =
    Provider<ReadingSessionRepository>((ref) {
  final boxManager = ref.watch(hiveBoxManagerProvider);
  return HiveReadingSessionRepository(boxManager);
});
