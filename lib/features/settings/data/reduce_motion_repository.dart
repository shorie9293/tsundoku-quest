import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/features/settings/domain/reduce_motion_setting.dart';

/// 動きを減らす設定のリポジトリ
///
/// SharedPreferences に設定の storageKey を保存・復元する。
class ReduceMotionRepository {
  static const String key = 'tsundoku_reduce_motion';

  const ReduceMotionRepository();

  /// 保存された設定を読み込む。
  /// 未保存、または不正値の場合は null（=system 扱い）。
  Future<ReduceMotionSetting?> loadReduceMotion() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(key)) return null;
    final value = prefs.getString(key);
    if (value == null) return null;
    for (final setting in ReduceMotionSetting.values) {
      if (setting.storageKey == value) return setting;
    }
    return null;
  }

  /// 設定を保存する。
  Future<void> saveReduceMotion(ReduceMotionSetting setting) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, setting.storageKey);
  }
}

/// 試練用のインメモリ実装。
class InMemoryReduceMotionRepository implements ReduceMotionRepository {
  ReduceMotionSetting? _saved;
  int _saveCount = 0;

  /// 直近に保存された設定（未保存は null）
  ReduceMotionSetting? get saved => _saved;

  /// 保存が呼ばれた回数
  int get saveCount => _saveCount;

  @override
  Future<ReduceMotionSetting?> loadReduceMotion() async => _saved;

  @override
  Future<void> saveReduceMotion(ReduceMotionSetting setting) async {
    _saved = setting;
    _saveCount++;
  }
}
