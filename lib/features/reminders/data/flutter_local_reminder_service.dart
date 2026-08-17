/// flutter_local_notifications によるローカル通知の具象実装
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'local_notification_scheduler.dart';

class FlutterLocalReminderService implements LocalNotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin;

  FlutterLocalReminderService(this._plugin);

  static const int _reminderId = 2001;
  static const String _channelId = 'reading_reminder';
  static const String _channelName = '読書リマインダー';

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
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

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
