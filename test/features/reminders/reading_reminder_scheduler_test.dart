import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import 'package:tsundoku_quest/features/reminders/data/local_notification_scheduler.dart';
import 'package:tsundoku_quest/features/reminders/domain/reading_reminder_scheduler.dart';

class MockLocalNotificationScheduler extends Mock
    implements LocalNotificationScheduler {}

void main() {
  setUpAll(() {
    registerFallbackValue(0);
    registerFallbackValue('');
  });

  group('buildNotificationBody', () {
    test('includes tsundoku count when > 0', () {
      final scheduler = ReadingReminderScheduler(MockLocalNotificationScheduler());
      expect(scheduler.buildNotificationBody(3), contains('3冊'));
      expect(scheduler.buildNotificationBody(3), contains('積読'));
    });

    test('returns a default message when count is 0', () {
      final scheduler = ReadingReminderScheduler(MockLocalNotificationScheduler());
      expect(scheduler.buildNotificationBody(0), isNotEmpty);
      expect(scheduler.buildNotificationBody(0), contains('読書'));
    });
  });

  group('applySettings', () {
    late MockLocalNotificationScheduler mock;
    late ReadingReminderScheduler scheduler;

    setUp(() {
      mock = MockLocalNotificationScheduler();
      scheduler = ReadingReminderScheduler(mock);
      when(() => mock.cancel()).thenAnswer((_) async {});
      when(() => mock.scheduleDaily(
            hour: any(named: 'hour'),
            minute: any(named: 'minute'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {});
    });

    test('schedules a daily reminder when enabled and tsundoku > 0', () async {
      const settings = ReadingReminderSettings(enabled: true, hour: 21, minute: 30);
      await scheduler.applySettings(settings: settings, tsundokuCount: 5);
      final captured = verify(() => mock.scheduleDaily(
            hour: 21,
            minute: 30,
            body: captureAny(named: 'body'),
          )).captured;
      expect(captured.single, contains('5冊'));
      verifyNever(() => mock.cancel());
    });

    test('cancels when disabled even with tsundoku books', () async {
      const settings = ReadingReminderSettings(enabled: false);
      await scheduler.applySettings(settings: settings, tsundokuCount: 5);
      verify(() => mock.cancel()).called(1);
      verifyNever(() => mock.scheduleDaily(
            hour: any(named: 'hour'),
            minute: any(named: 'minute'),
            body: any(named: 'body'),
          ));
    });

    test('cancels when there are no tsundoku books even if enabled', () async {
      const settings = ReadingReminderSettings(enabled: true);
      await scheduler.applySettings(settings: settings, tsundokuCount: 0);
      verify(() => mock.cancel()).called(1);
      verifyNever(() => mock.scheduleDaily(
            hour: any(named: 'hour'),
            minute: any(named: 'minute'),
            body: any(named: 'body'),
          ));
    });
  });
}
