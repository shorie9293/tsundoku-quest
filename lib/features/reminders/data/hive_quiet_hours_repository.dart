/// Hive 実装の静穏時間（おやすみモード）設定リポジトリ
///
/// `BoxNames.quietHours`（'quiet_hours_box'）に JSON 文字列で保存する。
/// 既存の [HiveReminderSettingsRepository] と同じ BoxManager 流儀に合わせ、
/// Hive の open/close は BoxManager に一元化する。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/features/reminders/domain/quiet_hours_settings.dart';

import 'quiet_hours_repository.dart';

class HiveQuietHoursRepository implements QuietHoursRepository {
  HiveQuietHoursRepository(this._boxManager, {this.openIfMissing = true});

  /// 保存キー（単一オブジェクト）。
  static const String keyName = 'quiet_hours_settings';

  final BoxManagerInterface _boxManager;

  /// false なら「既に open 済みの box を読むだけ」にし、無ければ
  /// [QuietHoursSettings.defaults] を返す。
  ///
  /// 通知経路の既定ガードはこれを false で使う。Hive 未初期化のまま
  /// `openBox` を呼ぶと Hive 内部で未処理の非同期エラーが発生し得るため、
  /// box の open はアプリ起動時（main.dart の openAllBoxes）と保存時のみに
  /// 限定する。
  final bool openIfMissing;

  Box<String>? _box;

  Future<Box<String>?> _getBox() async {
    if (_box != null && _box!.isOpen) return _box;
    try {
      if (Hive.isBoxOpen(BoxNames.quietHours)) {
        _box = Hive.box<String>(BoxNames.quietHours);
        return _box;
      }
      if (!openIfMissing) return null;
      _box = await _boxManager.getBox<String>(BoxNames.quietHours);
      return _box;
    } catch (e) {
      // Hive 未初期化・path 未設定などはここで握り潰し null を返す
      // （通知経路が例外やハングで止まらない）。
      debugPrint('[QuietHoursRepo] open failed: $e');
      return null;
    }
  }

  /// 破損・型不正・open 失敗は [QuietHoursSettings.defaults] へ落とす。
  @override
  Future<QuietHoursSettings> load() async {
    try {
      final box = await _getBox();
      if (box == null) return QuietHoursSettings.defaults();
      final raw = box.get(keyName);
      if (raw is! String) return QuietHoursSettings.defaults();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return QuietHoursSettings.defaults();
      }
      return QuietHoursSettings.fromJson(decoded);
    } catch (e) {
      debugPrint('[QuietHoursRepo] load failed: $e');
      return QuietHoursSettings.defaults();
    }
  }

  @override
  Future<void> save(QuietHoursSettings settings) async {
    try {
      final box = await _getBox() ?? await _boxManager.getBox<String>(BoxNames.quietHours);
      _box = box;
      await box.put(keyName, jsonEncode(settings.toJson()));
      await box.flush();
    } catch (e) {
      // 保存失敗は握り潰す（設定画面を壊さない）。
      debugPrint('[QuietHoursRepo] save failed: $e');
    }
  }
}
