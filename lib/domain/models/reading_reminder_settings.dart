import 'user_book.dart';

/// 読書リマインダーの設定
///
/// Hive（および必要に応じて SharedPreferences）に永続化する単一オブジェクト。
/// 積読（tsundoku）状態の本に対する毎日の読書習慣支援通知を管理する。
class ReadingReminderSettings {
  /// リマインダー有効/無効フラグ
  final bool enabled;

  /// 毎日の通知時刻（時, 0〜23）
  final int hour;

  /// 毎日の通知時刻（分, 0〜59）
  final int minute;

  /// 対象読書状態（デフォルトは積読）
  final BookStatus targetStatus;

  const ReadingReminderSettings({
    this.enabled = false,
    this.hour = 20,
    this.minute = 0,
    this.targetStatus = BookStatus.tsundoku,
  });

  factory ReadingReminderSettings.fromJson(Map<String, dynamic> json) {
    return ReadingReminderSettings(
      enabled: json['enabled'] as bool? ?? false,
      hour: json['hour'] as int? ?? 20,
      minute: json['minute'] as int? ?? 0,
      targetStatus:
          BookStatus.fromString(json['targetStatus'] as String? ?? 'tsundoku'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'hour': hour,
      'minute': minute,
      'targetStatus': targetStatus.value,
    };
  }

  ReadingReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    BookStatus? targetStatus,
  }) {
    return ReadingReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      targetStatus: targetStatus ?? this.targetStatus,
    );
  }
}
