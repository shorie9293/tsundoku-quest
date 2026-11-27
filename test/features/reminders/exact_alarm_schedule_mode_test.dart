// USE_EXACT_ALARM 撤去後の予約モード切替の試練。
//
// 検証対象:
//   - exactAlarmAllowed シーム false → zonedSchedule の androidScheduleMode が
//     inexactAllowWhileIdle（実引数を捕捉して検証）
//   - exactAlarmAllowed シーム true  → exactAllowWhileIdle
//   - シーム未注入（production 経路）では OS の権限照会結果に従う
//     （宣言が無い/拒否なら inexact に落ちる）
//   - AndroidManifest に USE_EXACT_ALARM が残っていないこと
// 現在時刻は必ず clock 注入で固定する（DateTime.now 直読み禁止）。
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tsundoku_quest/features/reminders/data/flutter_local_reminder_service.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours_service.dart';

class _MockNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class _MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

/// 入力をそのまま返す透過ガード（静穏時間なし＝予約モードだけを見る）。
class _PassThroughGuard extends QuietHoursGuard {
  @override
  Future<DateTime?> adjust(DateTime scheduled) async => scheduled;
}

/// zonedSchedule の実引数の写し（androidScheduleMode を主対象）。
class _ZonedCall {
  _ZonedCall(Invocation invocation)
      : id = invocation.positionalArguments[0] as int,
        scheduled = invocation.positionalArguments[3] as tz.TZDateTime,
        mode = invocation.namedArguments[#androidScheduleMode]
            as AndroidScheduleMode,
        match = invocation.namedArguments[#matchDateTimeComponents]
            as DateTimeComponents?,
        payload = invocation.namedArguments[#payload] as String?;

  final int id;
  final tz.TZDateTime scheduled;
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

  group('exactAlarmAllowed シームによる予約モード切替', () {
    test('シーム false: 実 zonedSchedule は inexactAllowWhileIdle', () async {
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
      expect(calls.single.mode, AndroidScheduleMode.inexactAllowWhileIdle);
      expect(calls.single.id, 2001);
      // 切替で予約内容（毎日繰り返し・遷移先 payload）は変わらない。
      expect(calls.single.match, DateTimeComponents.time);
      expect(calls.single.payload, isNotNull);
    });

    test('シーム true: 実 zonedSchedule は exactAllowWhileIdle', () async {
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

      expect(calls, hasLength(1));
      expect(calls.single.mode, AndroidScheduleMode.exactAllowWhileIdle);
      expect(calls.single.id, 2001);
      expect(calls.single.match, DateTimeComponents.time);
    });

    test('シームは予約のたびに照会される（キャッシュで固定されない）', () async {
      final plugin = _MockNotificationsPlugin();
      final calls = <_ZonedCall>[];
      _stubSchedule(plugin, calls);

      var allowed = false;
      final service = FlutterLocalReminderService(
        plugin,
        guard: _PassThroughGuard(),
        clock: _clockAt(2026, 11, 5, 9, 0),
        exactAlarmAllowed: () async => allowed,
      );

      await service.scheduleDaily(hour: 20, minute: 15, body: '1回目');
      allowed = true;
      await service.scheduleDaily(hour: 20, minute: 15, body: '2回目');

      expect(
        calls.map((c) => c.mode).toList(),
        [
          AndroidScheduleMode.inexactAllowWhileIdle,
          AndroidScheduleMode.exactAllowWhileIdle,
        ],
      );
    });
  });

  group('シーム未注入（production 既定経路）', () {
    test('Android 実装が無い環境では inexact に落ちる', () async {
      final plugin = _MockNotificationsPlugin();
      final calls = <_ZonedCall>[];
      _stubSchedule(plugin, calls);
      // resolvePlatformSpecificImplementation は未スタブ → null（非 Android）。
      when(
        () => plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>(),
      ).thenReturn(null);

      final service = FlutterLocalReminderService(
        plugin,
        guard: _PassThroughGuard(),
        clock: _clockAt(2026, 11, 5, 9, 0),
      );

      await service.scheduleDaily(hour: 20, minute: 15, body: '本文');

      expect(calls.single.mode, AndroidScheduleMode.inexactAllowWhileIdle);
    });

    test('OS の権限照会が false なら inexact（USE_EXACT_ALARM 前提が消えた）',
        () async {
      final plugin = _MockNotificationsPlugin();
      final android = _MockAndroidPlugin();
      final calls = <_ZonedCall>[];
      _stubSchedule(plugin, calls);
      when(
        () => plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>(),
      ).thenReturn(android);
      when(() => android.canScheduleExactNotifications())
          .thenAnswer((_) async => false);

      final service = FlutterLocalReminderService(
        plugin,
        guard: _PassThroughGuard(),
        clock: _clockAt(2026, 11, 5, 9, 0),
      );

      await service.scheduleDaily(hour: 20, minute: 15, body: '本文');

      expect(calls.single.mode, AndroidScheduleMode.inexactAllowWhileIdle);
    });

    test('OS の権限照会が true なら exact', () async {
      final plugin = _MockNotificationsPlugin();
      final android = _MockAndroidPlugin();
      final calls = <_ZonedCall>[];
      _stubSchedule(plugin, calls);
      when(
        () => plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>(),
      ).thenReturn(android);
      when(() => android.canScheduleExactNotifications())
          .thenAnswer((_) async => true);

      final service = FlutterLocalReminderService(
        plugin,
        guard: _PassThroughGuard(),
        clock: _clockAt(2026, 11, 5, 9, 0),
      );

      await service.scheduleDaily(hour: 20, minute: 15, body: '本文');

      expect(calls.single.mode, AndroidScheduleMode.exactAllowWhileIdle);
    });
  });

  group('AndroidManifest の宣言', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final source = manifest.readAsStringSync();

    test('USE_EXACT_ALARM を宣言しない（常時 true の抜け道を塞ぐ）', () {
      expect(source.contains('android.permission.USE_EXACT_ALARM'), isFalse);
    });

    test('SCHEDULE_EXACT_ALARM は残す（ユーザー許可で exact を使う）', () {
      expect(
        source.contains('android.permission.SCHEDULE_EXACT_ALARM'),
        isTrue,
      );
    });
  });
}
