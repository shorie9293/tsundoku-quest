// 読書リマインダーが OS 側で毎日繰り返すこと（および予約モード選択）の試練。
//
// 検証対象: FlutterLocalReminderService.scheduleDaily が
//   - matchDateTimeComponents: DateTimeComponents.time で予約する
//   - 正確アラーム権限の有無で androidScheduleMode を切り替える
//   - 静穏時間ガードの skip / defer を従来どおり扱う
//   - 同一IDへの上書き予約（cancel を挟まない）
// 現在時刻は必ず clock 注入で固定する（DateTime.now 直読み禁止）。
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tsundoku_quest/features/reminders/data/flutter_local_reminder_service.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours_service.dart';

class _MockNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

/// adjust の返り値を固定する差し替えガード（defer / skip を直接作る）。
class _StubGuard extends QuietHoursGuard {
  _StubGuard(this._result);

  final DateTime? _result;

  @override
  Future<DateTime?> adjust(DateTime scheduled) async => _result;
}

/// 入力をそのまま返す透過ガード（静穏時間なし）。
class _PassThroughGuard extends QuietHoursGuard {
  @override
  Future<DateTime?> adjust(DateTime scheduled) async => scheduled;
}

/// zonedSchedule の実引数（位置引数＋named 引数）の写し。
class _ZonedCall {
  _ZonedCall(Invocation invocation)
      : id = invocation.positionalArguments[0] as int,
        title = invocation.positionalArguments[1] as String?,
        body = invocation.positionalArguments[2] as String?,
        scheduled = invocation.positionalArguments[3] as tz.TZDateTime,
        details = invocation.positionalArguments[4] as NotificationDetails,
        mode = invocation.namedArguments[#androidScheduleMode]
            as AndroidScheduleMode,
        match = invocation.namedArguments[#matchDateTimeComponents]
            as DateTimeComponents?,
        payload = invocation.namedArguments[#payload] as String?;

  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime scheduled;
  final NotificationDetails details;
  final AndroidScheduleMode mode;
  final DateTimeComponents? match;
  final String? payload;
}

void _stubSchedule(_MockNotificationsPlugin plugin, List<_ZonedCall> sink) {
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
      matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      payload: any(named: 'payload'),
    ),
  ).thenAnswer((invocation) async {
    sink.add(_ZonedCall(invocation));
  });
}

void _verifyNeverScheduled(_MockNotificationsPlugin plugin) {
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
      matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      payload: any(named: 'payload'),
    ),
  );
}

/// 固定時刻を返す clock（tz.UTC 基準。ホスト TZ に依存しない）。
DateTime Function() _clockAt(int y, int m, int d, int h, int min) =>
    () => tz.TZDateTime(tz.UTC, y, m, d, h, min);

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    registerFallbackValue(tz.TZDateTime(tz.UTC, 2020));
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(UILocalNotificationDateInterpretation.absoluteTime);
    registerFallbackValue(DateTimeComponents.time);
    registerFallbackValue('');
    registerFallbackValue(0);
  });

  test('毎日繰り返し: matchDateTimeComponents に DateTimeComponents.time を渡す',
      () async {
    final plugin = _MockNotificationsPlugin();
    final calls = <_ZonedCall>[];
    _stubSchedule(plugin, calls);

    final service = FlutterLocalReminderService(
      plugin,
      guard: _PassThroughGuard(),
      clock: _clockAt(2026, 11, 5, 9, 0),
      exactAlarmAllowed: () async => false,
    );

    await service.scheduleDaily(hour: 20, minute: 15, body: '本文');

    expect(calls, hasLength(1));
    expect(calls.single.match, DateTimeComponents.time);
  });

  test('正確アラーム許可あり: androidScheduleMode は exactAllowWhileIdle', () async {
    final plugin = _MockNotificationsPlugin();
    final calls = <_ZonedCall>[];
    _stubSchedule(plugin, calls);

    final service = FlutterLocalReminderService(
      plugin,
      guard: _PassThroughGuard(),
      clock: _clockAt(2026, 11, 5, 9, 0),
      exactAlarmAllowed: () async => true,
    );

    await service.scheduleDaily(hour: 20, minute: 15, body: '本文');

    expect(calls.single.mode, AndroidScheduleMode.exactAllowWhileIdle);
  });

  test('正確アラーム許可なし: androidScheduleMode は inexactAllowWhileIdle', () async {
    final plugin = _MockNotificationsPlugin();
    final calls = <_ZonedCall>[];
    _stubSchedule(plugin, calls);

    final service = FlutterLocalReminderService(
      plugin,
      guard: _PassThroughGuard(),
      clock: _clockAt(2026, 11, 5, 9, 0),
      exactAlarmAllowed: () async => false,
    );

    await service.scheduleDaily(hour: 20, minute: 15, body: '本文');

    expect(calls.single.mode, AndroidScheduleMode.inexactAllowWhileIdle);
  });

  test('権限照会が例外でも inexact に落ちて予約は成立する', () async {
    final plugin = _MockNotificationsPlugin();
    final calls = <_ZonedCall>[];
    _stubSchedule(plugin, calls);

    final service = FlutterLocalReminderService(
      plugin,
      guard: _PassThroughGuard(),
      clock: _clockAt(2026, 11, 5, 9, 0),
      exactAlarmAllowed: () async => throw StateError('no platform'),
    );

    await service.scheduleDaily(hour: 20, minute: 15, body: '本文');

    expect(calls.single.mode, AndroidScheduleMode.inexactAllowWhileIdle);
  });

  test('ガードが skip(null) を返すと予約せず cancel する', () async {
    final plugin = _MockNotificationsPlugin();
    final calls = <_ZonedCall>[];
    _stubSchedule(plugin, calls);
    when(() => plugin.cancel(any())).thenAnswer((_) async {});

    final service = FlutterLocalReminderService(
      plugin,
      guard: _StubGuard(null),
      clock: _clockAt(2026, 11, 5, 23, 10),
      exactAlarmAllowed: () async => true,
    );

    await service.scheduleDaily(hour: 23, minute: 30, body: '本文');

    expect(calls, isEmpty);
    verify(() => plugin.cancel(2001)).called(1);
    _verifyNeverScheduled(plugin);
  });

  test('同日2回の scheduleDaily は同一IDへ2回・cancel を挟まない', () async {
    final plugin = _MockNotificationsPlugin();
    final calls = <_ZonedCall>[];
    _stubSchedule(plugin, calls);

    final service = FlutterLocalReminderService(
      plugin,
      guard: _PassThroughGuard(),
      clock: _clockAt(2026, 11, 5, 9, 0),
      exactAlarmAllowed: () async => false,
    );

    await service.scheduleDaily(hour: 20, minute: 15, body: '1回目');
    await service.scheduleDaily(hour: 20, minute: 15, body: '2回目');

    expect(calls, hasLength(2));
    expect(calls.map((c) => c.id), everyElement(2001));
    expect(calls.first.scheduled, calls.last.scheduled);
    verifyNever(() => plugin.cancel(any()));
  });

  test('defer: 繰延時刻（翌朝07:00）の時・分で予約する', () async {
    final plugin = _MockNotificationsPlugin();
    final calls = <_ZonedCall>[];
    _stubSchedule(plugin, calls);

    final service = FlutterLocalReminderService(
      plugin,
      guard: _StubGuard(tz.TZDateTime(tz.UTC, 2026, 11, 6, 7, 0)),
      clock: _clockAt(2026, 11, 5, 23, 10),
      exactAlarmAllowed: () async => false,
    );

    await service.scheduleDaily(hour: 23, minute: 30, body: '本文');

    final scheduled = calls.single.scheduled;
    expect(scheduled.hour, 7);
    expect(scheduled.minute, 0);
    expect(scheduled.day, 6);
    expect(calls.single.match, DateTimeComponents.time);
  });

  test('clock 注入で固定すれば暦が進んでも予約日は注入時刻に従う', () async {
    final plugin = _MockNotificationsPlugin();
    final calls = <_ZonedCall>[];
    _stubSchedule(plugin, calls);

    // 実時刻から遠く離れた日付を注入（DateTime.now 依存なら赤化する）。
    final service = FlutterLocalReminderService(
      plugin,
      guard: _PassThroughGuard(),
      clock: _clockAt(2030, 3, 1, 6, 30),
      exactAlarmAllowed: () async => false,
    );

    await service.scheduleDaily(hour: 6, minute: 30, body: '本文');

    final scheduled = calls.single.scheduled;
    expect(scheduled.year, 2030);
    expect(scheduled.month, 3);
    expect(scheduled.day, 2);
    expect(scheduled.hour, 6);
    expect(scheduled.minute, 30);
  });
}
