import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';

/// リマインダー設定の永続化リポジトリ
abstract class ReminderSettingsRepository {
  /// 保存済み設定を読み込む（未保存ならデフォルトを返す）
  Future<ReadingReminderSettings> load();

  /// 設定を保存する
  Future<void> save(ReadingReminderSettings settings);
}
