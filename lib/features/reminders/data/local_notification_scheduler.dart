/// ローカル通知スケジューラの抽象インターフェース
///
/// プラットフォーム固有の通知実装（flutter_local_notifications）を抽象化し、
/// 試練（テスト）で Mock 可能にする。
library;

abstract class LocalNotificationScheduler {
  /// 通知プラグインの初期化
  Future<void> initialize();

  /// 毎日 [hour]:[minute] に [body] を通知するようスケジュールする
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String body,
  });

  /// スケジュール済みの通知をキャンセルする
  Future<void> cancel();
}
