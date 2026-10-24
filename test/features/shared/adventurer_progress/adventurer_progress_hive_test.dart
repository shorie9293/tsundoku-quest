import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/hive_initializer.dart';
import 'package:tsundoku_quest/domain/models/adventurer_progress.dart';
import 'package:tsundoku_quest/features/shared/data/adventurer_progress_repository.dart';
import 'package:tsundoku_quest/shared/providers/adventurer_provider.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('adventurer_progress_');
    Hive.init(tempDir.path);
    hiveInitialized = true;
  });

  tearDownAll(() async {
    await Hive.close();
    hiveInitialized = false;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Hive 実体に保存し、別インスタンスから復元できる（往復一致）', () async {
    final repository = HiveAdventurerProgressRepository(HiveBoxManager());
    const progress = AdventurerProgress(
      level: 6,
      xp: 320,
      xpToNextLevel: 600,
      title: '本の探検家',
      readingDates: ['2026-10-10', '2026-10-11'],
    );

    await repository.save(progress);

    // 別インスタンス（=再起動相当）で読み直す
    final reopened = HiveAdventurerProgressRepository(HiveBoxManager());
    final loaded = await reopened.load();

    expect(loaded, progress);
    expect(loaded.title, '本の探検家');
  });

  test('adventurer_box の stats キーに JSON 文字列で保存される', () async {
    final box = await Hive.openBox<String>('adventurer_box');
    final raw = box.get(HiveAdventurerProgressRepository.statsKey);

    expect(raw, isNotNull);
    expect(raw, contains('"level":6'));
    expect(raw, contains('本の探検家'));
  });

  test('Hive 実体を介した再起動でレベルが保たれる（合成の親探針）', () async {
    final repository = HiveAdventurerProgressRepository(HiveBoxManager());

    final first = AdventurerNotifier(progressRepository: repository);
    await first.loadProgress();
    first.addXp(2500);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final second = AdventurerNotifier(
      progressRepository: HiveAdventurerProgressRepository(HiveBoxManager()),
    );
    await second.loadProgress();

    expect(second.state.level, first.state.level);
    expect(second.state.title, first.state.title);
    expect(second.state.level, greaterThan(1));
  });
}
