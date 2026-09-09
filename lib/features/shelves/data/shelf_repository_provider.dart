import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/domain/repositories/shelf_repository.dart';
import 'package:tsundoku_quest/features/shelves/data/hive_shelf_repository.dart';

/// ShelfRepository の Provider
///
/// HiveBoxManager が初期化されていれば Hive 永続化、それ以外は
/// インメモリ実装にフォールバックする（テスト／オフライン用）。
final shelfRepositoryProvider = Provider<ShelfRepository>((ref) {
  try {
    final boxManager = ref.read(hiveBoxManagerProvider);
    return HiveShelfRepository(boxManager);
  } catch (_) {
    return InMemoryShelfRepository();
  }
});
