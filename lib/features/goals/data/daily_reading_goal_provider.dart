/// 日次読書目標の Riverpod 配線
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/features/goals/data/daily_reading_goal_repository.dart';
import 'package:tsundoku_quest/features/goals/domain/daily_reading_goal.dart';

/// リポジトリ
///
/// HiveBoxManager が初期化されていれば Hive 永続化、それ以外は
/// インメモリ実装にフォールバックする（テスト／オフライン用）。
final dailyReadingGoalRepositoryProvider = Provider<DailyReadingGoalRepository>((ref) {
  try {
    final boxManager = ref.read(hiveBoxManagerProvider);
    return HiveDailyReadingGoalRepository(boxManager);
  } catch (_) {
    return InMemoryDailyReadingGoalRepository();
  }
});

/// 目標設定の状態管理
class DailyReadingGoalController extends StateNotifier<DailyReadingGoal> {
  DailyReadingGoalController(this._repository)
      : super(const DailyReadingGoal.empty());

  final DailyReadingGoalRepository _repository;

  /// 保存済み目標を読み込む
  Future<void> load() async {
    state = await _repository.load();
  }

  /// 日次目標を保存する（0 以下は未設定＝解除）
  Future<void> saveTarget({
    required int targetMinutes,
    DateTime? now,
  }) async {
    final goal = DailyReadingGoal(
      targetMinutes: targetMinutes > 0 ? targetMinutes : 0,
      updatedAt: (now ?? DateTime.now()).toUtc().toIso8601String(),
    );
    await _repository.save(goal);
    state = goal;
  }

  /// 目標を解除する
  Future<void> clear() async {
    const goal = DailyReadingGoal.empty();
    await _repository.save(goal);
    state = goal;
  }
}

final dailyReadingGoalControllerProvider =
    StateNotifierProvider<DailyReadingGoalController, DailyReadingGoal>((ref) {
  return DailyReadingGoalController(ref.watch(dailyReadingGoalRepositoryProvider))
    ..load();
});