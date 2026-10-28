/// flutter_local_notifications によるローカル通知の具象実装
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../domain/notification_route_resolver.dart';
import '../domain/quiet_hours_service.dart';
import 'local_notification_scheduler.dart';
import 'quiet_hours_guard_wiring.dart';

class FlutterLocalReminderService implements LocalNotificationScheduler {
  FlutterLocalReminderService(
    this._plugin, {
    QuietHoursGuard? guard,
    DateTime Function()? clock,
    this.onRouteSelected,
    Set<String>? allowedRoutes,
  })  : _guard = guard,
        _clock = clock,
        allowedRoutes = allowedRoutes ?? NotificationRoutes.all;

  final FlutterLocalNotificationsPlugin _plugin;

  /// 静穏時間ガード。null なら [QuietHoursGuardWiring] の既定生成点を使う
  /// （試練・未初期化環境では「静穏時間なし」に落ちる）。
  QuietHoursGuard? _guard;

  /// 現在時刻の供給元（試練で固定時刻を注入するための差し替えシーム）。
  final DateTime Function()? _clock;

  /// 遷移を許可する論理 route 名（`NotificationTapRouter` の対応表と同一集合）。
  final Set<String> allowedRoutes;

  /// 通知タップで解決できた遷移先の受け手。
  ///
  /// 未接続（起動順の都合）でも取りこぼさないよう、解決できた遷移先は
  /// 保留（[consumePendingRoute] で回収）にも保持できる。
  void Function(ResolvedNotificationRoute)? onRouteSelected;

  /// 起動前タップ（コールドスタート）で解決できた遷移先。1度だけ取り出せる。
  ResolvedNotificationRoute? _pendingRoute;

  /// 積読リマインダーの遷移先（書庫）。
  static const String reminderRoute = NotificationRoutes.library;

  static const int _reminderId = 2001;
  static const String _channelId = 'reading_reminder';
  static const String _channelName = '読書リマインダー';

  /// 明示注入が無ければ既定生成点から一度だけ生成する。
  QuietHoursGuard get _effectiveGuard =>
      _guard ??= QuietHoursGuardWiring.create();

  @override
  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const init = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    await _captureLaunchRoute();
  }

  /// 起動前にタップされた通知（コールドスタート）を解決して保留する。
  ///
  /// この時点では画面も router も無いため、ここでは遷移せず保留に留める。
  Future<void> _captureLaunchRoute() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return;
      _acceptPayload(details.notificationResponse?.payload, deliver: false);
    } catch (_) {
      // 通知基盤が無い環境（試練・未対応プラットフォーム）では起動を妨げない
    }
  }

  /// 生タップ（アプリ稼働中）の受け口。
  void _onNotificationResponse(NotificationResponse response) {
    _acceptPayload(response.payload, deliver: true);
  }

  /// payload を解決し、受け手があれば直送、無ければ保留する。
  void _acceptPayload(String? payload, {required bool deliver}) {
    final resolved = NotificationRouteResolver.resolve(
      payload,
      allowedRoutes: allowedRoutes,
    );
    if (resolved == null) return;
    final listener = onRouteSelected;
    if (deliver && listener != null) {
      listener(resolved);
      return;
    }
    _pendingRoute = resolved;
  }

  /// 保留中の遷移先を1度だけ取り出す（2度目以降は null）。
  ResolvedNotificationRoute? consumePendingRoute() {
    final pending = _pendingRoute;
    _pendingRoute = null;
    return pending;
  }

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String body,
  }) async {
    final clock = _clock;
    final now = clock != null
        ? tz.TZDateTime.from(clock(), tz.local)
        : tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // 静穏時間ガード: null なら送出しない、返却時刻が繰延時刻。
    final resolved = await _effectiveGuard.adjust(scheduledDate);
    if (resolved == null) {
      await cancel();
      return;
    }
    scheduledDate = tz.TZDateTime.from(resolved, tz.local);

    await _plugin.zonedSchedule(
      _reminderId,
      '積読のお知らせ',
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '毎日の積読読書リマインダー',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // タップ時の遷移先。予約時刻・繰り返し・ID・静穏時間の扱いは不変。
      payload: NotificationRouteResolver.buildPayload(reminderRoute),
    );
  }

  @override
  Future<void> cancel() async {
    await _plugin.cancel(_reminderId);
  }
}
