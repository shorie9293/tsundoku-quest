import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/reading_reminder_adapter.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/book_adapters.dart';
import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';

void main() {
  setUp(() {
    final tempDir = Directory.systemTemp.createTempSync('hive_reminder_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(ReadingReminderAdapter());
    Hive.registerAdapter(BookStatusAdapter());
  });

  tearDown(() async {
    await Hive.close();
  });

  test('persists and reads ReadingReminderSettings via Hive box', () async {
    final box = await Hive.openBox<ReadingReminderSettings>('reminder_test_box');
    const settings = ReadingReminderSettings(
      enabled: true,
      hour: 9,
      minute: 45,
      targetStatus: BookStatus.tsundoku,
    );
    await box.put('settings', settings);
    final loaded = box.get('settings');
    expect(loaded, isNotNull);
    expect(loaded!.enabled, isTrue);
    expect(loaded.hour, 9);
    expect(loaded.minute, 45);
    expect(loaded.targetStatus, BookStatus.tsundoku);
  });
}
