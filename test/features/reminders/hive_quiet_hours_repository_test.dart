import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/features/reminders/data/hive_quiet_hours_repository.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours_settings.dart';

/// 実 Hive を temp ディレクトリで使う最小の BoxManager。
class _TestBoxManager implements BoxManagerInterface {
  @override
  Future<Box<T>> getBox<T>(String name) async => await Hive.openBox<T>(name);

  @override
  Future<void> openAllBoxes() async {}

  @override
  Future<void> closeBox(String name) async {
    if (Hive.isBoxOpen(name)) await Hive.box(name).close();
  }

  @override
  Future<void> closeAllBoxes() async => await Hive.close();

  @override
  Future<void> clearBox(String name) async {
    final box = await getBox<dynamic>(name);
    await box.clear();
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hive_quiet_hours_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('save → load で設定が往復する', () async {
    final repo = HiveQuietHoursRepository(_TestBoxManager());
    final settings = QuietHoursSettings(
      enabled: true,
      startHour: 23,
      startMinute: 30,
      endHour: 6,
      endMinute: 45,
      policy: QuietHoursPolicy.skip,
    );

    await repo.save(settings);
    expect(await repo.load(), equals(settings));
  });

  test('未保存なら既定値（無効）を返す', () async {
    final repo = HiveQuietHoursRepository(_TestBoxManager());
    expect(await repo.load(), QuietHoursSettings.defaults());
  });

  test('破損 JSON は既定値へフォールバックする', () async {
    final repo = HiveQuietHoursRepository(_TestBoxManager());
    final box = await Hive.openBox<String>(BoxNames.quietHours);
    await box.put(HiveQuietHoursRepository.keyName, '{broken json');

    expect(await repo.load(), QuietHoursSettings.defaults());
  });

  test('型不正（Map でない JSON）も既定値へフォールバックする', () async {
    final repo = HiveQuietHoursRepository(_TestBoxManager());
    final box = await Hive.openBox<String>(BoxNames.quietHours);
    await box.put(HiveQuietHoursRepository.keyName, jsonEncode([1, 2, 3]));

    expect(await repo.load(), QuietHoursSettings.defaults());
  });

  test('openIfMissing=false は box 未 open でも既定値（例外なし）', () async {
    final repo = HiveQuietHoursRepository(
      _TestBoxManager(),
      openIfMissing: false,
    );
    expect(await repo.load(), QuietHoursSettings.defaults());
  });
}
