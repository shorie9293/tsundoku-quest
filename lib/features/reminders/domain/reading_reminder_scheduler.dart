import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import '../data/local_notification_scheduler.dart';

/// 読書リマインダーのスケジューリングを統括するサービス
///
/// 設定（有効/無効・通知時刻・対象状態）と積読冊数に応じて、
/// 毎日の通知をスケジュール／キャンセルする。
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

  /// 設定と積読冊数に基づいて通知をスケジュール/キャンセルする
  ///
  /// - 無効 or 積読 0 冊 → キャンセル
  /// - 有効 かつ 積読 > 0 冊 → 毎日 [settings.hour]:[settings.minute] にスケジュール
  Future<void> applySettings({
    required ReadingReminderSettings settings,
    required int tsundokuCount,
  }) async {
    if (!settings.enabled || tsundokuCount <= 0) {
      await _scheduler.cancel();
      return;
    }
    await _scheduler.scheduleDaily(
      hour: settings.hour,
      minute: settings.minute,
      body: buildNotificationBody(tsundokuCount),
    );
  }
}
