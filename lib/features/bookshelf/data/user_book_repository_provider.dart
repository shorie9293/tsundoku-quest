import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/infrastructure/hive/box_manager_provider.dart';
import '../../../domain/repositories/user_book_repository.dart';
import 'hive_user_book_repository.dart';

/// UserBookRepository の Riverpod Provider
/// Hive をプライマリデータストアとして使用する（Offline-First）
final userBookRepositoryProvider = Provider<UserBookRepository>((ref) {
  final boxManager = ref.watch(hiveBoxManagerProvider);
  return HiveUserBookRepository(boxManager);
});
