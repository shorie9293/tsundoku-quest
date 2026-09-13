/// 読書目標の進捗を集計する純粋ロジックサービス
///
/// Widget / Hive / Riverpod に依存せず、引数のリストからのみ集計する。
/// 不正な日付・未来日付は黙って集計外とする（統計で例外を投げない）。
library;

import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal.dart';

class ReadingGoalService {
  const ReadingGoalService._();

  /// 今月の読了数に対する進捗
  static ReadingGoalProgress monthlyProgress({
    required List<UserBook> books,
    required ReadingGoal goal,
    required DateTime now,
  }) {
    final current = now.toUtc();
    final count = _completedIn(
      books,
      now: current,
      matches: (dt) => dt.year == current.year && dt.month == current.month,
    );
    return ReadingGoalProgress(target: goal.monthlyTarget, achieved: count);
  }

  /// 今年の読了数に対する進捗
  static ReadingGoalProgress yearlyProgress({
    required List<UserBook> books,
    required ReadingGoal goal,
    required DateTime now,
  }) {
    final current = now.toUtc();
    final count = _completedIn(
      books,
      now: current,
      matches: (dt) => dt.year == current.year,
    );
    return ReadingGoalProgress(target: goal.yearlyTarget, achieved: count);
  }

  /// 指定期間（[start]〜[end]、両端含む）の読了数
  static int completedBetween({
    required List<UserBook> books,
    required DateTime start,
    required DateTime end,
  }) {
    if (end.isBefore(start)) return 0;
    final from = start.toUtc();
    final to = end.toUtc();
    return _completedIn(
      books,
      now: to,
      matches: (dt) => !dt.isBefore(from) && !dt.isAfter(to),
    );
  }

  static int _completedIn(
    List<UserBook> books, {
    required DateTime now,
    required bool Function(DateTime) matches,
  }) {
    var count = 0;
    for (final ub in books) {
      if (ub.status != BookStatus.completed) continue;
      final dt = _parse(ub.completedAt);
      if (dt == null) continue;
      if (dt.isAfter(now)) continue; // 未来日付は集計外
      if (matches(dt)) count++;
    }
    return count;
  }

  static DateTime? _parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso)?.toUtc();
  }
}
