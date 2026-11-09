/// バックアップが運ぶ「設定」の読み書き
///
/// 対象は SharedPreferences（テーマ・文字サイズ・動きを減らす）と
/// Hive（静穏時間・リマインダー・チュートリアル既読）。
/// 何を控えに載せるかは [kBackupSettingSpecs] の許可リストが決める。
///
/// 復元は「1キーずつ」適用する。型不一致・破損は [writeValue] が例外を
/// 投げ、呼び側（リポジトリ）が個別に握ってスキップする
/// （1つの壊れた設定で復元全体を落とさない）。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/core/logging/app_logger.dart';
import 'package:tsundoku_quest/domain/models/reading_reminder_settings.dart';
import 'package:tsundoku_quest/features/backup/domain/backup_settings_spec.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours_settings.dart';
import 'package:tsundoku_quest/features/settings/domain/reduce_motion_setting.dart';
import 'package:tsundoku_quest/features/settings/domain/text_scale_setting.dart';
import 'package:tsundoku_quest/features/settings/domain/theme_mode_setting.dart';

/// 設定の生読み・生書きの抽象
abstract class BackupSettingsStore {
  /// 許可リスト分の現在値を集める（未設定のキーは含めない＝省略）。
  ///
  /// 秘密キーは読み出し対象にしない（読まなければ漏れようがない）。
  Future<Map<String, Object?>> readRaw();

  /// 1キーを適用する。型不一致・不正値は例外（呼び側が個別に握る）。
  Future<void> writeValue(String key, Object? value);
}

/// Hive + SharedPreferences 実装
class HiveBackupSettingsStore implements BackupSettingsStore {
  HiveBackupSettingsStore(
    this._boxManager, {
    Future<SharedPreferences> Function()? prefs,
  }) : _prefs = prefs ?? SharedPreferences.getInstance;

  final BoxManagerInterface _boxManager;
  final Future<SharedPreferences> Function() _prefs;

  /// 静穏時間の保存キー（HiveQuietHoursRepository.keyName と同一）
  static const String quietHoursKeyName = 'quiet_hours_settings';

  @override
  Future<Map<String, Object?>> readRaw() async {
    final raw = <String, Object?>{};

    try {
      final prefs = await _prefs();
      _putIfNotNull(
          raw, 'tsundoku_theme_mode', prefs.getString('tsundoku_theme_mode'));
      _putIfNotNull(raw, 'tsundoku_text_scale', _scaleOf(prefs));
      _putIfNotNull(raw, 'tsundoku_reduce_motion',
          prefs.getString('tsundoku_reduce_motion'));
      // チュートリアル既読は TutorialPreferences（SharedPreferences）が正。
      _putIfNotNull(
          raw, 'tutorial_lore_seen', prefs.getBool('tutorial_lore_seen'));
      _putIfNotNull(raw, 'tutorial_operation_seen',
          prefs.getBool('tutorial_operation_seen'));
    } catch (e) {
      appLog.warn('[BackupSettings] prefs read failed (skipped): $e');
    }

    final quietHours = await _readBoxValue<String>(
      BoxNames.quietHours,
      quietHoursKeyName,
    );
    if (quietHours is String) raw['quiet_hours_settings'] = quietHours;

    final reminder = await _readReminderSettings();
    if (reminder != null) raw['reminder_settings'] = reminder;

    return raw;
  }

  @override
  Future<void> writeValue(String key, Object? value) async {
    switch (key) {
      case 'tsundoku_theme_mode':
        if (value is! String) {
          throw FormatException('tsundoku_theme_mode must be String: $value');
        }
        if (!ThemeModeSetting.values.any((m) => m.storageKey == value)) {
          throw FormatException('unknown theme mode: $value');
        }
        final prefs = await _prefs();
        await prefs.setString('tsundoku_theme_mode', value);
        return;

      case 'tsundoku_text_scale':
        if (value is! num) {
          throw FormatException('tsundoku_text_scale must be num: $value');
        }
        final scale = value.toDouble();
        if (!TextScaleSetting.isAllowed(scale)) {
          throw FormatException('disallowed text scale: $scale');
        }
        final prefs = await _prefs();
        await prefs.setDouble('tsundoku_text_scale', scale);
        return;

      case 'tsundoku_reduce_motion':
        if (value is! String) {
          throw FormatException(
              'tsundoku_reduce_motion must be String: $value');
        }
        if (!ReduceMotionSetting.values.any((s) => s.storageKey == value)) {
          throw FormatException('unknown reduce motion: $value');
        }
        final prefs = await _prefs();
        await prefs.setString('tsundoku_reduce_motion', value);
        return;

      case 'quiet_hours_settings':
        if (value is! String) {
          throw const FormatException('quiet_hours_settings must be String');
        }
        final map = _decodeMap(value, 'quiet_hours_settings');
        final settings = QuietHoursSettings.fromJson(map);
        // fromJson は破損時に既定へ落ちるため、正規化して一致する時だけ採用する
        // （黙って既定で上書きしない）。
        if (jsonEncode(settings.toJson()) != jsonEncode(map)) {
          throw const FormatException('quiet_hours_settings is invalid');
        }
        final box = await _boxManager.getBox<String>(BoxNames.quietHours);
        await box.put(quietHoursKeyName, jsonEncode(settings.toJson()));
        await box.flush();
        return;

      case 'reminder_settings':
        if (value is! String) {
          throw const FormatException('reminder_settings must be String');
        }
        final map = _decodeMap(value, 'reminder_settings');
        final settings = ReadingReminderSettings.fromJson(map);
        if (settings.hour < 0 ||
            settings.hour > 23 ||
            settings.minute < 0 ||
            settings.minute > 59) {
          throw FormatException('reminder time out of range: $map');
        }
        final box = await _boxManager
            .getBox<ReadingReminderSettings>(BoxNames.reminder);
        await BoxHelper.saveSingle(box, settings);
        return;

      case 'tutorial_lore_seen':
      case 'tutorial_operation_seen':
        if (value is! bool) {
          throw FormatException('$key must be bool: $value');
        }
        final prefs = await _prefs();
        await prefs.setBool(key, value);
        return;

      default:
        // 未知キー・秘密キーは書かない（呼び側の許可リスト判断を尊重）。
        throw FormatException('not backed up setting: $key');
    }
  }

  Map<String, dynamic> _decodeMap(String value, String key) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw FormatException('$key must be a JSON object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Object? _scaleOf(SharedPreferences prefs) {
    Object? raw;
    try {
      raw = prefs.get('tsundoku_text_scale');
    } catch (_) {
      return null;
    }
    if (raw is num) return raw.toDouble();
    return null;
  }

  Future<Object?> _readBoxValue<T>(String boxName, String key) async {
    try {
      final box = await _boxManager.getBox<T>(boxName);
      return box.get(key);
    } catch (e) {
      appLog.warn('[BackupSettings] box "$boxName" read failed: $e');
      return null;
    }
  }

  Future<String?> _readReminderSettings() async {
    try {
      final box =
          await _boxManager.getBox<ReadingReminderSettings>(BoxNames.reminder);
      final settings = BoxHelper.loadSingle(box);
      if (settings == null) return null;
      return jsonEncode(settings.toJson());
    } catch (e) {
      appLog.warn('[BackupSettings] reminder read failed: $e');
      return null;
    }
  }
}

void _putIfNotNull(Map<String, Object?> target, String key, Object? value) {
  if (value != null) target[key] = value;
}
