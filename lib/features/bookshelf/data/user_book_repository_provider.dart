import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/domain/repositories/user_book_repository.dart';
import 'hive_user_book_repository.dart';

/// UserBookRepository の Riverpod Provider
/// Hive ローカル永続化をプライマリ、Supabase はバックグラウンド同期（別途）
final userBookRepositoryProvider = Provider<UserBookRepository>((ref) {
  final boxManager = ref.watch(hiveBoxManagerProvider);
  return HiveUserBookRepository(boxManager);
});
