import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import '../data/local_notification_scheduler.dart';
import 'quiet_hours_service.dart';
import 'quiet_hours_settings.dart';

/// 読書リマインダーのスケジューリングを統括するサービス
///
/// 設定（有効/無効・通知時刻・対象状態）と積読冊数に応じて、
/// 毎日の通知をスケジュール／キャンセルする。
///
/// [applySettings] に [QuietHoursSettings] を渡すと、静穏時間ガードを通した
/// うえで予約時刻を決める（defer なら繰延時刻、skip なら予約しない）。
class ReadingReminderScheduler {
  final LocalNotificationScheduler _scheduler;

  ReadingReminderScheduler(this._scheduler);

  /// 通知本文を生成する（純関数・試練可能）
  String buildNotificationBody(int tsundokuCount) {
    if (tsundokuCount <= 0) {
      return '今日も読書を楽しみましょう！';
    }
    return '積読が$tsundokuCount冊あります。今日も読書の冒険に出ましょう！';
  }

  /// [from] 以降で最初に [hour]:[minute] を迎えるローカル時刻を返す。
  ///
  /// 純関数（[from] は必ず引数。実時計は読まない）。
  static DateTime nextOccurrence(DateTime from, int hour, int minute) {
    var target = DateTime(from.year, from.month, from.day, hour, minute);
    if (!target.isAfter(from)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  /// 設定と積読冊数に基づいて通知をスケジュール/キャンセルする
  ///
  /// - 無効 or 積読 0 冊 → キャンセル
  /// - 有効 かつ 積読 > 0 冊 → 毎日 [settings.hour]:[settings.minute] にスケジュール
  /// - [quietHours] が有効で予約時刻が静穏時間内 → policy に従い繰延 or 予約しない
  Future<void> applySettings({
    required ReadingReminderSettings settings,
    required int tsundokuCount,
    QuietHoursSettings? quietHours,
    DateTime? now,
  }) async {
    if (!settings.enabled || tsundokuCount <= 0) {
      await _scheduler.cancel();
      return;
    }

    var hour = settings.hour;
    var minute = settings.minute;

    if (quietHours != null && quietHours.enabled) {
      final scheduled = nextOccurrence(
        now ?? DateTime.now(),
        settings.hour,
        settings.minute,
      );
      final resolved = QuietHoursService.resolveDelivery(quietHours, scheduled);
      if (resolved == null) {
        // skip: 静穏時間内の通知は予約しない（既存予約も解除）。
        await _scheduler.cancel();
        return;
      }
      hour = resolved.hour;
      minute = resolved.minute;
    }

    await _scheduler.scheduleDaily(
      hour: hour,
      minute: minute,
      body: buildNotificationBody(tsundokuCount),
    );
  }
}
