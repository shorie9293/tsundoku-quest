import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal.dart';

void main() {
  group('ReadingGoal', () {
    test('未設定は isConfigured=false', () {
      const goal = ReadingGoal.empty();
      expect(goal.isConfigured, isFalse);
      expect(goal.isMonthlySet, isFalse);
      expect(goal.isYearlySet, isFalse);
    });

    test('JSON往復で値が保存される', () {
      const goal = ReadingGoal(
        monthlyTarget: 2,
        yearlyTarget: 24,
        updatedAt: '2026-09-13T00:00:00.000Z',
      );
      final restored = ReadingGoal.fromJson(goal.toJson());
      expect(restored, goal);
    });

    test('破損値（負値・非数値）は0へ丸める', () {
      final restored = ReadingGoal.fromJson({
        'monthlyTarget': -5,
        'yearlyTarget': 'abc',
      });
      expect(restored.monthlyTarget, 0);
      expect(restored.yearlyTarget, 0);
      expect(restored.updatedAt, '');
    });

    test('数値文字列は受理する', () {
      final restored = ReadingGoal.fromJson({'monthlyTarget': '3'});
      expect(restored.monthlyTarget, 3);
    });

    test('copyWith は指定値のみ置換する', () {
      const goal = ReadingGoal(monthlyTarget: 1, yearlyTarget: 12);
      final updated = goal.copyWith(monthlyTarget: 3);
      expect(updated.monthlyTarget, 3);
      expect(updated.yearlyTarget, 12);
    });
  });

  group('ReadingGoalProgress', () {
    test('未設定のときは notSet バッジ', () {
      const progress = ReadingGoalProgress(target: 0, achieved: 5);
      expect(progress.isSet, isFalse);
      expect(progress.badge, ReadingGoalBadge.notSet);
      expect(progress.ratio, 0);
    });

    test('達成0は notStarted', () {
      const progress = ReadingGoalProgress(target: 4, achieved: 0);
      expect(progress.badge, ReadingGoalBadge.notStarted);
    });

    test('進捗率に応じてバッジが進む', () {
      expect(const ReadingGoalProgress(target: 10, achieved: 1).badge,
          ReadingGoalBadge.started);
      expect(const ReadingGoalProgress(target: 10, achieved: 5).badge,
          ReadingGoalBadge.halfway);
      expect(const ReadingGoalProgress(target: 10, achieved: 8).badge,
          ReadingGoalBadge.almost);
      expect(const ReadingGoalProgress(target: 10, achieved: 10).badge,
          ReadingGoalBadge.achieved);
    });

    test('超過達成は ratio=1 に丸め、remaining=0', () {
      const progress = ReadingGoalProgress(target: 2, achieved: 5);
      expect(progress.ratio, 1);
      expect(progress.percent, 100);
      expect(progress.remaining, 0);
      expect(progress.isAchieved, isTrue);
    });

    test('残り冊数を算出する', () {
      const progress = ReadingGoalProgress(target: 10, achieved: 3);
      expect(progress.remaining, 7);
      expect(progress.percent, 30);
    });
  });
}
