/// flutter_local_notifications によるローカル通知の具象実装
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../domain/quiet_hours_service.dart';
import 'local_notification_scheduler.dart';
import 'quiet_hours_guard_wiring.dart';

class FlutterLocalReminderService implements LocalNotificationScheduler {
  FlutterLocalReminderService(
    this._plugin, {
    QuietHoursGuard? guard,
    DateTime Function()? clock,
  })  : _guard = guard,
        _clock = clock;

  final FlutterLocalNotificationsPlugin _plugin;

  /// 静穏時間ガード。null なら [QuietHoursGuardWiring] の既定生成点を使う
  /// （試練・未初期化環境では「静穏時間なし」に落ちる）。
  QuietHoursGuard? _guard;

  /// 現在時刻の供給元（試練で固定時刻を注入するための差し替えシーム）。
  final DateTime Function()? _clock;

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
    await _plugin.initialize(init);
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
    );
  }

  @override
  Future<void> cancel() async {
    await _plugin.cancel(_reminderId);
  }
}
