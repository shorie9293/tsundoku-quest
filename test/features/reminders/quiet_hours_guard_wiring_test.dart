import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tsundoku_quest/features/reminders/data/flutter_local_reminder_service.dart';
import 'package:tsundoku_quest/features/reminders/data/quiet_hours_guard_wiring.dart';
import 'package:tsundoku_quest/features/reminders/data/quiet_hours_repository.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours_settings.dart';
import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import 'package:tsundoku_quest/features/reminders/data/local_notification_scheduler.dart';
import 'package:tsundoku_quest/features/reminders/domain/reading_reminder_scheduler.dart';

class _FakeScheduler implements LocalNotificationScheduler {
  int scheduleCount = 0;
  int cancelCount = 0;
  int? hour;
  int? minute;
  String? body;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String body,
  }) async {
    scheduleCount++;
    this.hour = hour;
    this.minute = minute;
    this.body = body;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }
}

class _MockNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

DateTime _at(int hour, int minute) => DateTime(2020, 1, 15, hour, minute);

/// `adjust` はローカル時刻を返すため、瞬間（instant）で比較する。
Matcher _sameMoment(DateTime expected) => predicate<DateTime>(
  (d) => d.isAtSameMomentAs(expected),
  'same moment as $expected',
);

void main() {
  tearDown(QuietHoursGuardWiring.reset);

  group('QuietHoursGuardWiring（既定生成点の差し替えシーム）', () {
    test('repositoryFactory 差し替えで既定生成経路のままガードが効く', () async {
      QuietHoursGuardWiring.repositoryFactory =
          () => InMemoryQuietHoursRepository(
                QuietHoursSettings(enabled: true, startHour: 22, endHour: 7),
              );

      final guard = QuietHoursGuardWiring.create();
      expect(
        await guard.adjust(_at(23, 30)),
        _sameMoment(DateTime(2020, 1, 16, 7, 0)),
      );
      // 静穏時間外はそのまま
      expect(await guard.adjust(_at(12, 0)), _at(12, 0));
    });

    test('skip 設定ならガードは null を返す', () async {
      QuietHoursGuardWiring.repositoryFactory =
          () => InMemoryQuietHoursRepository(
                QuietHoursSettings(
                  enabled: true,
                  startHour: 22,
                  endHour: 7,
                  policy: QuietHoursPolicy.skip,
                ),
              );
      expect(await QuietHoursGuardWiring.create().adjust(_at(2, 0)), isNull);
    });

    test('差し替え無し（既定）は静穏時間なしに落ち、例外にならない', () async {
      final guard = QuietHoursGuardWiring.create();
      expect(await guard.adjust(_at(2, 0)), _at(2, 0));
    });

    test('reset で差し替えが既定に戻る', () async {
      QuietHoursGuardWiring.repositoryFactory =
          () => InMemoryQuietHoursRepository(QuietHoursSettings(enabled: true));
      QuietHoursGuardWiring.reset();
      expect(await QuietHoursGuardWiring.create().adjust(_at(2, 0)), _at(2, 0));
    });

    test('InMemoryQuietHoursRepository は load/save を数える', () async {
      final repo = InMemoryQuietHoursRepository();
      await repo.load();
      await repo.save(
          QuietHoursSettings(enabled: true, policy: QuietHoursPolicy.skip));
      expect(repo.loadCount, 1);
      expect(repo.saveCount, 1);
      expect(repo.current.policy, QuietHoursPolicy.skip);
    });

    test('NoopQuietHoursRepository は常に既定値を返す', () async {
      final repo = NoopQuietHoursRepository();
      await repo.save(QuietHoursSettings(enabled: true));
      expect(await repo.load(), QuietHoursSettings.defaults());
    });
  });

  group('ReadingReminderScheduler の静穏時間配線', () {
    test('defer: 静穏時間内の予約時刻は終了時刻へ繰り延べる', () async {
      final fake = _FakeScheduler();
      final scheduler = ReadingReminderScheduler(fake);
      await scheduler.applySettings(
        settings:
            const ReadingReminderSettings(enabled: true, hour: 23, minute: 0),
        tsundokuCount: 3,
        quietHours:
            QuietHoursSettings(enabled: true, startHour: 22, endHour: 7),
        now: _at(23, 10),
      );
      expect(fake.scheduleCount, 1);
      expect(fake.hour, 7);
      expect(fake.minute, 0);
      expect(fake.cancelCount, 0);
    });

    test('skip: 静穏時間内なら予約せずキャンセルする', () async {
      final fake = _FakeScheduler();
      final scheduler = ReadingReminderScheduler(fake);
      await scheduler.applySettings(
        settings:
            const ReadingReminderSettings(enabled: true, hour: 23, minute: 0),
        tsundokuCount: 3,
        quietHours: QuietHoursSettings(
          enabled: true,
          startHour: 22,
          endHour: 7,
          policy: QuietHoursPolicy.skip,
        ),
        now: _at(23, 10),
      );
      expect(fake.scheduleCount, 0);
      expect(fake.cancelCount, 1);
    });

    test('静穏時間外は従来どおり設定時刻に予約する', () async {
      final fake = _FakeScheduler();
      final scheduler = ReadingReminderScheduler(fake);
      await scheduler.applySettings(
        settings:
            const ReadingReminderSettings(enabled: true, hour: 20, minute: 15),
        tsundokuCount: 2,
        quietHours:
            QuietHoursSettings(enabled: true, startHour: 22, endHour: 7),
        now: _at(9, 0),
      );
      expect(fake.hour, 20);
      expect(fake.minute, 15);
    });

    test('静穏時間が無効なら設定時刻のまま', () async {
      final fake = _FakeScheduler();
      final scheduler = ReadingReminderScheduler(fake);
      await scheduler.applySettings(
        settings:
            const ReadingReminderSettings(enabled: true, hour: 23, minute: 30),
        tsundokuCount: 1,
        quietHours:
            QuietHoursSettings(enabled: false, startHour: 22, endHour: 7),
        now: _at(23, 10),
      );
      expect(fake.hour, 23);
      expect(fake.minute, 30);
    });

    test('quietHours 未指定なら従来挙動（後方互換）', () async {
      final fake = _FakeScheduler();
      final scheduler = ReadingReminderScheduler(fake);
      await scheduler.applySettings(
        settings:
            const ReadingReminderSettings(enabled: true, hour: 21, minute: 0),
        tsundokuCount: 1,
      );
      expect(fake.hour, 21);
      expect(fake.minute, 0);
    });

    test('nextOccurrence は当日過去なら翌日にする', () {
      expect(
        ReadingReminderScheduler.nextOccurrence(_at(23, 10), 7, 0),
        _sameMoment(DateTime(2020, 1, 16, 7, 0)),
      );
      expect(
        ReadingReminderScheduler.nextOccurrence(_at(9, 0), 20, 15),
        _sameMoment(DateTime(2020, 1, 15, 20, 15)),
      );
    });
  });

  group('QuietHoursRepositoryGuard', () {
    test('リポジトリの設定どおりに adjust する', () async {
      final guard = QuietHoursRepositoryGuard(
        InMemoryQuietHoursRepository(
          QuietHoursSettings(enabled: true, startHour: 0, endHour: 6),
        ),
      );
      expect(
        await guard.adjust(_at(1, 0)),
        _sameMoment(DateTime(2020, 1, 15, 6, 0)),
      );
      expect(await guard.adjust(_at(12, 0)), _at(12, 0));
    });
  });

  group('FlutterLocalReminderService の実スケジューラ配線', () {
    setUpAll(() {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.UTC);
      registerFallbackValue(tz.TZDateTime(tz.UTC, 2020));
      registerFallbackValue(const NotificationDetails());
      registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
      registerFallbackValue(
        UILocalNotificationDateInterpretation.absoluteTime,
      );
      registerFallbackValue('');
    });

    test('defer: 繰延時刻（翌朝 07:00）で zonedSchedule する', () async {
      final plugin = _MockNotificationsPlugin();
      when(
        () => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          uiLocalNotificationDateInterpretation: any(
            named: 'uiLocalNotificationDateInterpretation',
          ),
        ),
      ).thenAnswer((_) async {});

      final service = FlutterLocalReminderService(
        plugin,
        guard: QuietHoursRepositoryGuard(
          InMemoryQuietHoursRepository(
            QuietHoursSettings(enabled: true, startHour: 22, endHour: 7),
          ),
        ),
        clock: () => _at(23, 10),
      );

      await service.scheduleDaily(hour: 23, minute: 30, body: '本文');

      final captured = verify(
        () => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          captureAny(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          uiLocalNotificationDateInterpretation: any(
            named: 'uiLocalNotificationDateInterpretation',
          ),
        ),
      ).captured;
      final scheduled = captured.single as DateTime;
      // tz.local はヘッドレスでは UTC になり得るため、壁時計でなく
      // 「同一の瞬間」で照合する（実機の TZ に依存しない）。
      expect(
        scheduled.isAtSameMomentAs(_at(7, 0).add(const Duration(days: 1))),
        isTrue,
        reason: '翌朝 07:00 へ繰り延べられた瞬間であること: $scheduled',
      );
    });

    test('skip: 予約せずキャンセルする', () async {
      final plugin = _MockNotificationsPlugin();
      when(() => plugin.cancel(any())).thenAnswer((_) async {});

      final service = FlutterLocalReminderService(
        plugin,
        guard: QuietHoursRepositoryGuard(
          InMemoryQuietHoursRepository(
            QuietHoursSettings(
              enabled: true,
              startHour: 22,
              endHour: 7,
              policy: QuietHoursPolicy.skip,
            ),
          ),
        ),
        clock: () => _at(23, 10),
      );

      await service.scheduleDaily(hour: 23, minute: 30, body: '本文');

      verify(() => plugin.cancel(any())).called(1);
      verifyNever(
        () => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          uiLocalNotificationDateInterpretation: any(
            named: 'uiLocalNotificationDateInterpretation',
          ),
        ),
      );
    });

    test('静穏時間外は設定時刻のまま zonedSchedule する', () async {
      final plugin = _MockNotificationsPlugin();
      when(
        () => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          uiLocalNotificationDateInterpretation: any(
            named: 'uiLocalNotificationDateInterpretation',
          ),
        ),
      ).thenAnswer((_) async {});

      final service = FlutterLocalReminderService(
        plugin,
        guard: QuietHoursRepositoryGuard(
          InMemoryQuietHoursRepository(
            QuietHoursSettings(enabled: true, startHour: 22, endHour: 7),
          ),
        ),
        clock: () => _at(9, 0),
      );

      await service.scheduleDaily(hour: 20, minute: 15, body: '本文');

      final captured = verify(
        () => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          captureAny(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          uiLocalNotificationDateInterpretation: any(
            named: 'uiLocalNotificationDateInterpretation',
          ),
        ),
      ).captured;
      final scheduled = captured.single as DateTime;
      expect(scheduled.hour, 20);
      expect(scheduled.minute, 15);
    });
  });
}
