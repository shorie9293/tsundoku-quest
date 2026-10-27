import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import 'package:tsundoku_quest/features/reminders/data/local_notification_scheduler.dart';
import 'package:tsundoku_quest/features/reminders/data/quiet_hours_repository.dart';
import 'package:tsundoku_quest/features/reminders/data/reminder_providers.dart';
import 'package:tsundoku_quest/features/reminders/data/reminder_settings_repository.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours_settings.dart';
import 'package:tsundoku_quest/features/reminders/presentation/quiet_hours_settings_screen.dart';
import 'package:tsundoku_quest/features/reminders/presentation/reminder_settings_screen.dart';

/// 固定時刻（実時計と突き合わせない十分過去の UTC 時刻 = 深夜 23:30）。
final DateTime _fixedNow = DateTime(2020, 1, 15, 23, 30);

class _FakeReminderSettingsRepository implements ReminderSettingsRepository {
  ReadingReminderSettings stored = const ReadingReminderSettings();

  @override
  Future<ReadingReminderSettings> load() async => stored;

  @override
  Future<void> save(ReadingReminderSettings settings) async {
    stored = settings;
  }
}

class _FakeScheduler implements LocalNotificationScheduler {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String body,
  }) async {}

  @override
  Future<void> cancel() async {}
}

Widget _quietApp({
  required InMemoryQuietHoursRepository repository,
  ValueChanged<QuietHoursSettings>? onSaved,
}) {
  return MaterialApp(
    home: QuietHoursSettingsScreen(
      repository: repository,
      now: _fixedNow,
      onSaved: onSaved,
    ),
  );
}

Widget _reminderApp(
    {WidgetBuilder? quietHoursScreenBuilder,
    QuietHoursRepository? repository}) {
  return ProviderScope(
    overrides: [
      hiveReminderSettingsRepositoryProvider.overrideWithValue(
        _FakeReminderSettingsRepository(),
      ),
      localNotificationSchedulerProvider.overrideWithValue(_FakeScheduler()),
      quietHoursRepositoryProvider.overrideWithValue(
        InMemoryQuietHoursRepository(),
      ),
    ],
    child: MaterialApp(
      home: ReminderSettingsScreen(
        quietHoursRepository: repository,
        quietHoursScreenBuilder: quietHoursScreenBuilder,
      ),
    ),
  );
}

void main() {
  group('QuietHoursSettingsScreen', () {
    testWidgets('初期状態は無効で、プレビューが無効表示になる', (tester) async {
      await tester
          .pumpWidget(_quietApp(repository: InMemoryQuietHoursRepository()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(AppKeys.quietHoursScreen), findsOneWidget);
      expect(find.byKey(AppKeys.quietHoursToggle), findsOneWidget);
      expect(find.byKey(AppKeys.quietHoursPreview), findsOneWidget);
      expect(find.text('静穏時間は無効です'), findsOneWidget);
      // 無効時は時刻・policy 選択は出さない
      expect(find.byKey(AppKeys.quietHoursStartHour), findsNothing);
      expect(find.byKey(AppKeys.quietHoursSaveButton), findsOneWidget);
    });

    testWidgets('有効化すると開始/終了時刻と policy 選択が現れる', (tester) async {
      await tester
          .pumpWidget(_quietApp(repository: InMemoryQuietHoursRepository()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(AppKeys.quietHoursToggle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(AppKeys.quietHoursStartHour), findsOneWidget);
      expect(find.byKey(AppKeys.quietHoursEndHour), findsOneWidget);
      expect(
        find.byKey(AppKeys.quietHoursPolicyOption('defer')),
        findsOneWidget,
      );
      expect(
        find.byKey(AppKeys.quietHoursPolicyOption('skip')),
        findsOneWidget,
      );
      // 22:00〜07:00（日跨ぎ）は翌朝 07:00 へ繰り延べる旨を表示
      expect(
        find.text('22:00〜07:00 の通知は翌朝 07:00 に繰り延べます'),
        findsOneWidget,
      );
    });

    testWidgets('保存でリポジトリへ永続化し onSaved を呼ぶ', (tester) async {
      final repository = InMemoryQuietHoursRepository();
      QuietHoursSettings? saved;
      await tester.pumpWidget(
        _quietApp(repository: repository, onSaved: (s) => saved = s),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(AppKeys.quietHoursToggle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.byKey(AppKeys.quietHoursSaveButton));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.quietHoursSaveButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.saveCount, 1);
      expect(repository.current.enabled, isTrue);
      expect(saved, isNotNull);
      expect(saved!.enabled, isTrue);
      expect(find.text('静穏時間を保存しました'), findsOneWidget);
    });

    testWidgets('skip を選ぶとプレビューが「行いません」に変わる', (tester) async {
      await tester.pumpWidget(
        _quietApp(
          repository: InMemoryQuietHoursRepository(
            QuietHoursSettings(enabled: true, startHour: 22, endHour: 7),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(
        find.byKey(AppKeys.quietHoursPolicyOption('skip')),
      );
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.quietHoursPolicyOption('skip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('22:00〜07:00 の通知は行いません'), findsOneWidget);
    });

    testWidgets('保存済み設定を読み込んで反映する（日跨ぎ・静穏時間内）', (tester) async {
      await tester.pumpWidget(
        _quietApp(
          repository: InMemoryQuietHoursRepository(
            QuietHoursSettings(
              enabled: true,
              startHour: 22,
              endHour: 7,
              policy: QuietHoursPolicy.defer,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // now = 23:30 は静穏時間内
      expect(find.text('ただいま静穏時間内です'), findsOneWidget);
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(AppKeys.quietHoursToggle),
      );
      expect(toggle.value, isTrue);
    });
  });

  group('ReminderSettingsScreen の導線', () {
    testWidgets('未注入なら静穏時間の導線を出さない', (tester) async {
      await tester.pumpWidget(_reminderApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(AppKeys.quietHoursEntry), findsNothing);
      expect(find.byKey(AppKeys.reminderSettingsScreen), findsOneWidget);
    });

    testWidgets('リポジトリ注入時は導線が出てタップで画面遷移する', (tester) async {
      await tester.pumpWidget(
        _reminderApp(repository: InMemoryQuietHoursRepository()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(AppKeys.quietHoursEntry), findsOneWidget);

      await tester.ensureVisible(find.byKey(AppKeys.quietHoursEntry));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.quietHoursEntry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(AppKeys.quietHoursScreen), findsOneWidget);
    });

    testWidgets('ビルダー注入時も導線が出て差し替え画面へ遷移する', (tester) async {
      await tester.pumpWidget(
        _reminderApp(
          quietHoursScreenBuilder: (_) =>
              const Scaffold(body: Text('QUIET_STUB')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.byKey(AppKeys.quietHoursEntry));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.quietHoursEntry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('QUIET_STUB'), findsOneWidget);
    });
  });
}
