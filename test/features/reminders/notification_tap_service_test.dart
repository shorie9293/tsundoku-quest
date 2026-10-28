import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tsundoku_quest/features/reminders/data/flutter_local_reminder_service.dart';
import 'package:tsundoku_quest/features/reminders/domain/notification_route_resolver.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours_settings.dart';
import 'package:tsundoku_quest/features/reminders/data/quiet_hours_repository.dart';

class _MockNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

/// チャネル呼出を await しない（プラグイン API は全て mocktail で差し替える）。
FlutterLocalReminderService _service(
  _MockNotificationsPlugin plugin, {
  void Function(ResolvedNotificationRoute)? onRouteSelected,
  Set<String>? allowedRoutes,
}) {
  return FlutterLocalReminderService(
    plugin,
    guard: QuietHoursRepositoryGuard(
      InMemoryQuietHoursRepository(QuietHoursSettings(enabled: false)),
    ),
    onRouteSelected: onRouteSelected,
    allowedRoutes: allowedRoutes,
  );
}

void _stubInitialize(_MockNotificationsPlugin plugin) {
  when(
    () => plugin.initialize(
      any(),
      onDidReceiveNotificationResponse: any(
        named: 'onDidReceiveNotificationResponse',
      ),
    ),
  ).thenAnswer((_) async => true);
}

void _stubLaunchDetails(
  _MockNotificationsPlugin plugin, {
  NotificationAppLaunchDetails? details,
}) {
  when(() => plugin.getNotificationAppLaunchDetails())
      .thenAnswer((_) async => details);
}

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    registerFallbackValue(tz.TZDateTime(tz.UTC, 2020));
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(UILocalNotificationDateInterpretation.absoluteTime);
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue('');
  });

  group('通知タップの受け口', () {
    test('initialize は onDidReceiveNotificationResponse を設定する', () async {
      final plugin = _MockNotificationsPlugin();
      _stubInitialize(plugin);
      _stubLaunchDetails(plugin);

      await _service(plugin).initialize();

      verify(
        () => plugin.initialize(
          any(),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
        ),
      ).called(1);
    });

    test('コールバック設定済みなら 生タップが onRouteSelected へ届く', () async {
      final plugin = _MockNotificationsPlugin();
      _stubInitialize(plugin);
      _stubLaunchDetails(plugin);

      void Function(NotificationResponse)? captured;
      when(
        () => plugin.initialize(
          any(),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
        ),
      ).thenAnswer((invocation) async {
        captured = invocation.namedArguments[#onDidReceiveNotificationResponse]
            as void Function(NotificationResponse)?;
        return true;
      });

      final received = <ResolvedNotificationRoute>[];
      final service = _service(plugin, onRouteSelected: received.add);
      await service.initialize();

      captured!(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: '{"route":"library"}',
        ),
      );

      expect(received, [ResolvedNotificationRoute(route: 'library')]);
      // 直送できたので保留には残らない
      expect(service.consumePendingRoute(), isNull);
    });

    test('未知 route のタップは onRouteSelected へ届かず保留にも残らない', () async {
      final plugin = _MockNotificationsPlugin();
      _stubInitialize(plugin);
      _stubLaunchDetails(plugin);

      void Function(NotificationResponse)? captured;
      when(
        () => plugin.initialize(
          any(),
          onDidReceiveNotificationResponse: any(
            named: 'onDidReceiveNotificationResponse',
          ),
        ),
      ).thenAnswer((invocation) async {
        captured = invocation.namedArguments[#onDidReceiveNotificationResponse]
            as void Function(NotificationResponse)?;
        return true;
      });

      final received = <ResolvedNotificationRoute>[];
      final service = _service(plugin, onRouteSelected: received.add);
      await service.initialize();

      captured!(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: '{"route":"nope"}',
        ),
      );
      captured!(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'broken',
        ),
      );

      expect(received, isEmpty);
      expect(service.consumePendingRoute(), isNull);
    });

    test('起動経由タップは pendingRoute に保持され、consume で1度だけ取り出せる',
        () async {
      final plugin = _MockNotificationsPlugin();
      _stubInitialize(plugin);
      _stubLaunchDetails(
        plugin,
        details: const NotificationAppLaunchDetails(
          true,
          notificationResponse: NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: '{"route":"reading","id":"ub-3"}',
          ),
        ),
      );

      final received = <ResolvedNotificationRoute>[];
      final service = _service(plugin, onRouteSelected: received.add);
      await service.initialize();

      // 起動経由は listener 未接続でも取りこぼさない（保留のみ）
      expect(received, isEmpty);
      expect(
        service.consumePendingRoute(),
        ResolvedNotificationRoute(route: 'reading', id: 'ub-3'),
      );
      expect(service.consumePendingRoute(), isNull);
    });

    test('通知起動でない / 起動情報なしなら保留は空', () async {
      for (final details in <NotificationAppLaunchDetails?>[
        null,
        const NotificationAppLaunchDetails(false),
        const NotificationAppLaunchDetails(true),
      ]) {
        final plugin = _MockNotificationsPlugin();
        _stubInitialize(plugin);
        _stubLaunchDetails(plugin, details: details);
        final service = _service(plugin);
        await service.initialize();
        expect(service.consumePendingRoute(), isNull);
      }
    });

    test('allowedRoutes を絞れば許可外 route は保留されない', () async {
      final plugin = _MockNotificationsPlugin();
      _stubInitialize(plugin);
      _stubLaunchDetails(
        plugin,
        details: const NotificationAppLaunchDetails(
          true,
          notificationResponse: NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: '{"route":"library"}',
          ),
        ),
      );

      final service = _service(plugin, allowedRoutes: {'reading'});
      await service.initialize();
      expect(service.consumePendingRoute(), isNull);
    });
  });

  group('payload 付与（発火側）', () {
    test('zonedSchedule に解決可能な payload が載る', () async {
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
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      await _service(plugin).scheduleDaily(hour: 20, minute: 15, body: '本文');

      final payload = verify(
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
          payload: captureAny(named: 'payload'),
        ),
      ).captured.single as String?;

      // 積読リマインダーは書庫（library）へ導く。
      expect(
        NotificationRouteResolver.resolve(
          payload,
          allowedRoutes: NotificationRoutes.all,
        ),
        ResolvedNotificationRoute(route: NotificationRoutes.library),
      );
    });
  });
}
