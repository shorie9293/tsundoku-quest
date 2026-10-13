/// 読書達成バッジコレクションの Riverpod 配線
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/badges/data/badge_record_repository.dart';
import 'package:tsundoku_quest/features/badges/domain/badge_collection_service.dart';
import 'package:tsundoku_quest/features/badges/domain/badge_definition.dart';

/// リポジトリ
///
/// HiveBoxManager が初期化されていれば Hive 永続化、それ以外は
/// インメモリ実装にフォールバックする（テスト／オフライン用）。
final badgeRecordRepositoryProvider = Provider<BadgeRecordRepository>((ref) {
  try {
    final boxManager = ref.read(hiveBoxManagerProvider);
    return HiveBadgeRecordRepository(boxManager);
  } catch (_) {
    return InMemoryBadgeRecordRepository();
  }
});

/// バッジコレクションの状態管理
///
/// 初期 state は null（未ロード）。[load] 完了後に確定値が入る。
class BadgeCollectionController extends StateNotifier<BadgeCollection?> {
  BadgeCollectionController(this._repository) : super(null);

  final BadgeRecordRepository _repository;

  /// セッション・蔵書から進捗を算出し、獲得日時を記録して state へ反映する
  Future<void> load({
    required List<ReadingSession> sessions,
    required List<UserBook> userBooks,
    required DateTime now,
  }) async {
    final base = BadgeCollectionService.build(
      sessions: sessions,
      userBooks: userBooks,
      now: now,
    );

    final saved = await _repository.load();
    final earnedIds = base.earned.map((b) => b.definition.id).toList();
    final recorded = saved.recordAll(earnedIds, now: now);
    if (recorded != saved) {
      await _repository.save(recorded);
    }

    final earnedAtById = <String, DateTime>{};
    recorded.earnedAtById.forEach((id, raw) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        earnedAtById[id] = parsed;
      }
    });

    state = BadgeCollectionService.attachEarnedAt(base, earnedAtById);
  }
}

final badgeCollectionControllerProvider =
    StateNotifierProvider<BadgeCollectionController, BadgeCollection?>((ref) {
  return BadgeCollectionController(ref.watch(badgeRecordRepositoryProvider));
});