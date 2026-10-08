import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/goals/data/daily_reading_goal_provider.dart';
import 'package:tsundoku_quest/features/goals/data/daily_reading_goal_repository.dart';
import 'package:tsundoku_quest/features/goals/domain/daily_reading_goal.dart';

void main() {
  group('InMemoryDailyReadingGoalRepository', () {
    test('初期値は empty', () async {
      final repo = InMemoryDailyReadingGoalRepository();
      expect(await repo.load(), const DailyReadingGoal.empty());
      expect(repo.current.isSet, isFalse);
    });

    test('initial を渡せる', () async {
      const initial = DailyReadingGoal(targetMinutes: 25);
      final repo = InMemoryDailyReadingGoalRepository(initial: initial);
      expect(await repo.load(), initial);
      expect(repo.current, initial);
    });

    test('save 往復: save 後に load/current が更新される', () async {
      final repo = InMemoryDailyReadingGoalRepository();
      const goal = DailyReadingGoal(targetMinutes: 45, updatedAt: '2026-10-09T00:00:00Z');
      await repo.save(goal);
      expect(repo.current, goal);
      expect(await repo.load(), goal);
      expect(repo.current.isSet, isTrue);
    });

    test('save の上書き', () async {
      final repo = InMemoryDailyReadingGoalRepository();
      await repo.save(const DailyReadingGoal(targetMinutes: 10));
      await repo.save(const DailyReadingGoal(targetMinutes: 20, updatedAt: 'u2'));
      expect(repo.current.targetMinutes, 20);
      expect(repo.current.updatedAt, 'u2');
    });
  });

  group('DailyReadingGoalController', () {
    test('saveTarget(>0) が repository に到達する', () async {
      final repo = InMemoryDailyReadingGoalRepository();
      final container = ProviderContainer(overrides: [
        dailyReadingGoalRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(dailyReadingGoalControllerProvider.notifier);

      await controller.saveTarget(
        targetMinutes: 60,
        now: DateTime.parse('2026-10-09T00:00:00Z'),
      );
      expect(repo.current.targetMinutes, 60);
      expect(repo.current.updatedAt, startsWith('2026-10-09T00:00:00'));
      expect(container.read(dailyReadingGoalControllerProvider).targetMinutes, 60);
    });

    test('saveTarget の now 未指定は現在時刻（UTC ISO8601）を使う', () async {
      final repo = InMemoryDailyReadingGoalRepository();
      final container = ProviderContainer(overrides: [
        dailyReadingGoalRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(dailyReadingGoalControllerProvider.notifier);
      await controller.saveTarget(targetMinutes: 15);
      expect(repo.current.updatedAt, isNotEmpty);
      expect(DateTime.tryParse(repo.current.updatedAt)?.isUtc, isTrue);
    });

    test('saveTarget(<=0) は未設定（0）として保存する', () async {
      final repo = InMemoryDailyReadingGoalRepository();
      final container = ProviderContainer(overrides: [
        dailyReadingGoalRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(dailyReadingGoalControllerProvider.notifier);

      await controller.saveTarget(targetMinutes: -3);
      expect(repo.current.targetMinutes, 0);
      expect(repo.current.isSet, isFalse);
      expect(container.read(dailyReadingGoalControllerProvider).isSet, isFalse);

      await controller.saveTarget(targetMinutes: 0);
      expect(repo.current.targetMinutes, 0);
    });

    test('load() で repository の値が state に入る', () async {
      const initial = DailyReadingGoal(targetMinutes: 90, updatedAt: 'z');
      final repo = InMemoryDailyReadingGoalRepository(initial: initial);
      final container = ProviderContainer(overrides: [
        dailyReadingGoalRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(dailyReadingGoalControllerProvider.notifier);
      await controller.load();
      expect(container.read(dailyReadingGoalControllerProvider), initial);
    });

    test('clear() は未設定を保存し state も空にする', () async {
      final repo = InMemoryDailyReadingGoalRepository();
      final container = ProviderContainer(overrides: [
        dailyReadingGoalRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(dailyReadingGoalControllerProvider.notifier);
      await controller.saveTarget(targetMinutes: 30);
      expect(repo.current.isSet, isTrue);

      await controller.clear();
      expect(repo.current, const DailyReadingGoal.empty());
      expect(container.read(dailyReadingGoalControllerProvider).isSet, isFalse);
    });

    test('provider 既定実装は DailyReadingGoalRepository を返す（Hive 可否は環境依存）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = container.read(dailyReadingGoalRepositoryProvider);
      expect(repo, isA<DailyReadingGoalRepository>());
    });
  });
}