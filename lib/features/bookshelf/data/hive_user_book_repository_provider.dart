/// Riverpod provider for HiveUserBookRepository
///
/// Provides a UserBookRepository backed by Hive local persistence.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/domain/repositories/user_book_repository.dart';
import 'hive_user_book_repository.dart';

/// Hive-based UserBookRepository provider
final hiveUserBookRepositoryProvider = Provider<UserBookRepository>((ref) {
  final boxManager = ref.watch(hiveBoxManagerProvider);
  return HiveUserBookRepository(boxManager);
});
