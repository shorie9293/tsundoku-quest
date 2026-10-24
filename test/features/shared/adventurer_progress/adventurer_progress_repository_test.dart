import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/adventurer_progress.dart';
import 'package:tsundoku_quest/features/shared/data/adventurer_progress_repository.dart';

/// Hive を一切開かない BoxManager（未初期化環境の再現用）
class _NeverUsedBoxManager implements BoxManagerInterface {
  @override
  Future<Box<T>> getBox<T>(String name) {
    throw StateError('box must not be opened in this test');
  }

  @override
  Future<void> openAllBoxes() async {}

  @override
  Future<void> closeBox(String name) async {}

  @override
  Future<void> closeAllBoxes() async {}

  @override
  Future<void> clearBox(String name) async {}
}

void main() {
  group('InMemoryAdventurerProgressRepository', () {
    test('保存した値をそのまま読み出せる', () async {
      final repository = InMemoryAdventurerProgressRepository();
      const progress = AdventurerProgress(
        level: 3,
        xp: 20,
        xpToNextLevel: 400,
        title: '書庫の見習い',
        readingDates: ['2026-10-07'],
      );

      await repository.save(progress);
      final loaded = await repository.load();

      expect(loaded, progress);
      expect(repository.saveCount, 1);
      expect(repository.current, progress);
    });

    test('初期値は駆け出し状態', () async {
      final repository = InMemoryAdventurerProgressRepository();
      final loaded = await repository.load();

      expect(loaded.level, 1);
      expect(loaded.xp, 0);
      expect(loaded.title, '書庫の見習い');
      expect(loaded.readingDates, isEmpty);
    });
  });

  group('HiveAdventurerProgressRepository（Hive未初期化時）', () {
    test('load は例外を投げず駆け出し状態を返す', () async {
      final repository = HiveAdventurerProgressRepository(_NeverUsedBoxManager());

      final loaded = await repository.load();

      expect(loaded.level, 1);
      expect(loaded.title, '書庫の見習い');
    });

    test('save は例外を投げず捨てられる', () async {
      final repository = HiveAdventurerProgressRepository(_NeverUsedBoxManager());

      await expectLater(
        repository.save(const AdventurerProgress(
          level: 4,
          xp: 5,
          xpToNextLevel: 500,
          title: '書庫の見習い',
          readingDates: [],
        )),
        completes,
      );
    });
  });
}
