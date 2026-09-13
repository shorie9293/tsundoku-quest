/// 読書目標の Riverpod 配線
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager_provider.dart';
import 'package:tsundoku_quest/features/goals/data/reading_goal_repository.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal_service.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

/// リポジトリ
///
/// HiveBoxManager が初期化されていれば Hive 永続化、それ以外は
/// インメモリ実装にフォールバックする（テスト／オフライン用）。
final readingGoalRepositoryProvider = Provider<ReadingGoalRepository>((ref) {
  try {
    final boxManager = ref.read(hiveBoxManagerProvider);
    return HiveReadingGoalRepository(boxManager);
  } catch (_) {
    return InMemoryReadingGoalRepository();
  }
});

/// 目標設定の状態管理
class ReadingGoalController extends StateNotifier<ReadingGoal> {
  ReadingGoalController(this._repository) : super(const ReadingGoal.empty());

  final ReadingGoalRepository _repository;

  /// 保存済み目標を読み込む
  Future<void> load() async {
    state = await _repository.load();
  }

  /// 月間・年間の目標を保存する（0 以下は未設定＝解除）
  Future<void> saveTargets({
    required int monthlyTarget,
    required int yearlyTarget,
    DateTime? now,
  }) async {
    final goal = ReadingGoal(
      monthlyTarget: monthlyTarget > 0 ? monthlyTarget : 0,
      yearlyTarget: yearlyTarget > 0 ? yearlyTarget : 0,
      updatedAt: (now ?? DateTime.now()).toUtc().toIso8601String(),
    );
    await _repository.save(goal);
    state = goal;
  }

  /// 目標を全解除する
  Future<void> clear() async {
    const goal = ReadingGoal.empty();
    await _repository.save(goal);
    state = goal;
  }
}

final readingGoalControllerProvider =
    StateNotifierProvider<ReadingGoalController, ReadingGoal>((ref) {
  return ReadingGoalController(ref.watch(readingGoalRepositoryProvider))
    ..load();
});

/// 今月の進捗
final monthlyGoalProgressProvider = Provider<ReadingGoalProgress>((ref) {
  final books = ref.watch(bookDataProvider).userBooks;
  final goal = ref.watch(readingGoalControllerProvider);
  return ReadingGoalService.monthlyProgress(
    books: books,
    goal: goal,
    now: DateTime.now(),
  );
});

/// 今年の進捗
final yearlyGoalProgressProvider = Provider<ReadingGoalProgress>((ref) {
  final books = ref.watch(bookDataProvider).userBooks;
  final goal = ref.watch(readingGoalControllerProvider);
  return ReadingGoalService.yearlyProgress(
    books: books,
    goal: goal,
    now: DateTime.now(),
  );
});
