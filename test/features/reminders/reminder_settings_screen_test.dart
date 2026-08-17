import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import 'package:tsundoku_quest/features/reminders/data/local_notification_scheduler.dart';
import 'package:tsundoku_quest/features/reminders/data/reminder_settings_repository.dart';
import 'package:tsundoku_quest/features/reminders/data/reminder_providers.dart';
import 'package:tsundoku_quest/features/reminders/presentation/reminder_settings_screen.dart';

class FakeReminderSettingsRepository implements ReminderSettingsRepository {
  ReadingReminderSettings stored = const ReadingReminderSettings();

  @override
  Future<ReadingReminderSettings> load() async => stored;

  @override
  Future<void> save(ReadingReminderSettings settings) async {
    stored = settings;
  }
}

class FakeLocalNotificationScheduler implements LocalNotificationScheduler {
  bool initialized = false;
  bool cancelled = false;
  int? scheduledHour;
  int? scheduledMinute;
  String? scheduledBody;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String body,
  }) async {
    scheduledHour = hour;
    scheduledMinute = minute;
    scheduledBody = body;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}

Widget _testApp({
  required FakeReminderSettingsRepository repo,
  required FakeLocalNotificationScheduler scheduler,
}) {
  return ProviderScope(
    overrides: [
      hiveReminderSettingsRepositoryProvider.overrideWithValue(repo),
      localNotificationSchedulerProvider.overrideWithValue(scheduler),
    ],
    child: const MaterialApp(home: ReminderSettingsScreen()),
  );
}

void main() {
  testWidgets('renders screen with toggle and time tile showing 20:00',
      (tester) async {
    await tester.pumpWidget(_testApp(
      repo: FakeReminderSettingsRepository(),
      scheduler: FakeLocalNotificationScheduler(),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.reminderSettingsScreen), findsOneWidget);
    expect(find.byKey(AppKeys.reminderEnabledSwitch), findsOneWidget);
    expect(find.byKey(AppKeys.reminderTimeTile), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
  });

  testWidgets('toggling the switch persists enabled=true to repository',
      (tester) async {
    final repo = FakeReminderSettingsRepository();
    await tester.pumpWidget(_testApp(
      repo: repo,
      scheduler: FakeLocalNotificationScheduler(),
    ));
    await tester.pumpAndSettle();

    Switch switchBefore = tester.widget<Switch>(
      find.byKey(AppKeys.reminderEnabledSwitch),
    );
    expect(switchBefore.value, isFalse);

    await tester.tap(find.byKey(AppKeys.reminderEnabledSwitch));
    await tester.pumpAndSettle();

    expect(repo.stored.enabled, isTrue);
    Switch switchAfter = tester.widget<Switch>(
      find.byKey(AppKeys.reminderEnabledSwitch),
    );
    expect(switchAfter.value, isTrue);
  });

  testWidgets('tapping the time tile opens the time picker dialog',
      (tester) async {
    await tester.pumpWidget(_testApp(
      repo: FakeReminderSettingsRepository(),
      scheduler: FakeLocalNotificationScheduler(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.reminderTimeTile));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
  });
}
