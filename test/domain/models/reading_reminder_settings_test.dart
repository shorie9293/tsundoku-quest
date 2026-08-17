import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';

void main() {
  group('ReadingReminderSettings defaults', () {
    test('default settings are disabled at 20:00 targeting tsundoku', () {
      const s = ReadingReminderSettings();
      expect(s.enabled, isFalse);
      expect(s.hour, 20);
      expect(s.minute, 0);
      expect(s.targetStatus, BookStatus.tsundoku);
    });
  });

  group('copyWith', () {
    test('updates enabled while keeping other fields', () {
      const s = ReadingReminderSettings();
      final s2 = s.copyWith(enabled: true);
      expect(s2.enabled, isTrue);
      expect(s2.hour, 20);
      expect(s2.minute, 0);
    });

    test('updates time', () {
      const s = ReadingReminderSettings();
      final s2 = s.copyWith(hour: 7, minute: 30);
      expect(s2.hour, 7);
      expect(s2.minute, 30);
    });

    test('updates targetStatus', () {
      const s = ReadingReminderSettings();
      final s2 = s.copyWith(targetStatus: BookStatus.reading);
      expect(s2.targetStatus, BookStatus.reading);
    });
  });

  group('serialization', () {
    test('toJson/fromJson round-trip', () {
      const s = ReadingReminderSettings(
        enabled: true,
        hour: 8,
        minute: 15,
        targetStatus: BookStatus.tsundoku,
      );
      final restored = ReadingReminderSettings.fromJson(s.toJson());
      expect(restored.enabled, isTrue);
      expect(restored.hour, 8);
      expect(restored.minute, 15);
      expect(restored.targetStatus, BookStatus.tsundoku);
    });

    test('fromJson fills defaults for missing keys', () {
      final s = ReadingReminderSettings.fromJson(const {});
      expect(s.enabled, isFalse);
      expect(s.hour, 20);
      expect(s.minute, 0);
      expect(s.targetStatus, BookStatus.tsundoku);
    });
  });
}
