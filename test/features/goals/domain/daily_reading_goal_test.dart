import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/goals/domain/daily_reading_goal.dart';

void main() {
  group('DailyReadingGoal', () {
    test('デフォルトは未設定', () {
      const goal = DailyReadingGoal();
      expect(goal.targetMinutes, 0);
      expect(goal.updatedAt, '');
      expect(goal.isSet, isFalse);
    });

    test('empty() コンストラクタは未設定を返す', () {
      const goal = DailyReadingGoal.empty();
      expect(goal.targetMinutes, 0);
      expect(goal.updatedAt, '');
      expect(goal.isSet, isFalse);
    });

    test('isSet は targetMinutes > 0 で true', () {
      const goal = DailyReadingGoal(targetMinutes: 30);
      expect(goal.isSet, isTrue);
    });

    test('fromJson: 正常な JSON を復元する', () {
      final goal = DailyReadingGoal.fromJson({
        'targetMinutes': 45,
        'updatedAt': '2026-01-01T00:00:00Z',
      });
      expect(goal.targetMinutes, 45);
      expect(goal.updatedAt, '2026-01-01T00:00:00Z');
    });

    test('fromJson 破損耐性: 負値は 0 へ', () {
      final goal = DailyReadingGoal.fromJson({'targetMinutes': -5});
      expect(goal.targetMinutes, 0);
    });

    test('fromJson 破損耐性: 非数値は 0 へ', () {
      final goal = DailyReadingGoal.fromJson({'targetMinutes': 'abc'});
      expect(goal.targetMinutes, 0);
    });

    test('fromJson 破損耐性: 欠落は 0 と \'\' へ', () {
      final goal = DailyReadingGoal.fromJson({});
      expect(goal.targetMinutes, 0);
      expect(goal.updatedAt, '');
    });

    test('fromJson 破損耐性: updatedAt 非文字列は \'\' へ', () {
      final goal = DailyReadingGoal.fromJson({
        'targetMinutes': 10,
        'updatedAt': 42,
      });
      expect(goal.targetMinutes, 10);
      expect(goal.updatedAt, '');
    });

    test('fromJson: double 型の数値も許容する', () {
      final goal = DailyReadingGoal.fromJson({'targetMinutes': 20.0});
      expect(goal.targetMinutes, 20);
    });

    test('toJson/fromJson 往復', () {
      const goal = DailyReadingGoal(targetMinutes: 60, updatedAt: '2026-02-02T10:00:00Z');
      final restored = DailyReadingGoal.fromJson(goal.toJson());
      expect(restored, goal);
    });

    test('copyWith: 一部だけ更新する', () {
      const goal = DailyReadingGoal(targetMinutes: 30, updatedAt: 'a');
      final updated = goal.copyWith(targetMinutes: 90);
      expect(updated.targetMinutes, 90);
      expect(updated.updatedAt, 'a');
    });

    test('copyWith: 引数なしは同一値', () {
      const goal = DailyReadingGoal(targetMinutes: 30, updatedAt: 'a');
      expect(goal.copyWith(), goal);
    });

    test('== と hashCode', () {
      const a = DailyReadingGoal(targetMinutes: 30, updatedAt: 'x');
      const b = DailyReadingGoal(targetMinutes: 30, updatedAt: 'x');
      const c = DailyReadingGoal(targetMinutes: 60, updatedAt: 'x');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}