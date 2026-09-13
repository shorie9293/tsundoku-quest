import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/features/goals/data/reading_goal_provider.dart';
import 'package:tsundoku_quest/features/goals/data/reading_goal_repository.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal.dart';

import '../../../test_helpers.dart';

void main() {
  group('InMemoryReadingGoalRepository', () {
    test('未設定のとき empty を返す', () async {
      final repo = InMemoryReadingGoalRepository();
      expect(await repo.load(), const ReadingGoal.empty());
    });

    test('save → load で往復する', () async {
      final repo = InMemoryReadingGoalRepository();
      await repo.save(const ReadingGoal(monthlyTarget: 2, yearlyTarget: 24));
      final loaded = await repo.load();
      expect(loaded.monthlyTarget, 2);
      expect(loaded.yearlyTarget, 24);
    });
  });

  group('ReadingGoalController', () {
    test('saveTargets は負値・0を未設定として保存する', () async {
      final repo = InMemoryReadingGoalRepository();
      final controller = ReadingGoalController(repo);
      await controller.saveTargets(
        monthlyTarget: -3,
        yearlyTarget: 0,
        now: DateTime.utc(2026, 9, 13),
      );
      expect(controller.state.isConfigured, isFalse);
      expect((await repo.load()).monthlyTarget, 0);
    });

    test('saveTargets は updatedAt をUTCで記録し状態を更新する', () async {
      final repo = InMemoryReadingGoalRepository();
      final controller = ReadingGoalController(repo);
      await controller.saveTargets(
        monthlyTarget: 2,
        yearlyTarget: 24,
        now: DateTime.utc(2026, 9, 13, 1, 2, 3),
      );
      expect(controller.state.monthlyTarget, 2);
      expect(controller.state.yearlyTarget, 24);
      expect(
        controller.state.updatedAt,
        DateTime.utc(2026, 9, 13, 1, 2, 3).toIso8601String(),
      );
    });

    test('load は保存済み目標を読み込む', () async {
      final repo = InMemoryReadingGoalRepository(
        initial: const ReadingGoal(monthlyTarget: 4),
      );
      final controller = ReadingGoalController(repo);
      await controller.load();
      expect(controller.state.monthlyTarget, 4);
    });

    test('clear は目標を全解除する', () async {
      final repo = InMemoryReadingGoalRepository(
        initial: const ReadingGoal(monthlyTarget: 4, yearlyTarget: 40),
      );
      final controller = ReadingGoalController(repo);
      await controller.clear();
      expect(controller.state.isConfigured, isFalse);
      expect((await repo.load()).isConfigured, isFalse);
    });
  });

  group('HiveReadingGoalRepository', () {
    late HiveBoxManager boxManager;

    setUpAll(() {
      initTestHive();
      boxManager = HiveBoxManager();
    });

    tearDownAll(() async {
      await Hive.close();
    });

    test('save → load で往復し、boxへJSON文字列で保存される', () async {
      final repo = HiveReadingGoalRepository(boxManager);
      await repo.save(const ReadingGoal(
        monthlyTarget: 2,
        yearlyTarget: 24,
        updatedAt: '2026-09-13T00:00:00.000Z',
      ));
      final loaded = await repo.load();
      expect(loaded.monthlyTarget, 2);
      expect(loaded.yearlyTarget, 24);

      final box = await boxManager.getBox<String>(BoxNames.readingGoal);
      expect(box.get(HiveReadingGoalRepository.goalKey), isA<String>());
    });

    test('未保存時は empty を返す', () async {
      final box = await boxManager.getBox<String>(BoxNames.readingGoal);
      await box.clear();
      final repo = HiveReadingGoalRepository(boxManager);
      expect(await repo.load(), const ReadingGoal.empty());
    });

    test('破損JSONは empty へフォールバックする（例外を投げない）', () async {
      final box = await boxManager.getBox<String>(BoxNames.readingGoal);
      await box.put(HiveReadingGoalRepository.goalKey, '{壊れたJSON');
      final repo = HiveReadingGoalRepository(boxManager);
      expect(await repo.load(), const ReadingGoal.empty());
    });
  });
}
