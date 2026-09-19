import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/features/settings/domain/text_scale_setting.dart';

/// 文字サイズ（UIスケール）設定のリポジトリ
///
/// SharedPreferences にスケール倍率を保存・復元する。
/// アプリ全体のテキストは [TextScaler.linear] で拡大縮小される
/// （MaterialApp.builder の MediaQuery で上書き）。
class TextScaleRepository {
  static const String key = 'tsundoku_text_scale';

  const TextScaleRepository();

  /// 保存されたスケール倍率を読み込む。
  /// 未保存、または許可外の値の場合は null（=1.0 扱い）。
  Future<double?> loadScale() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(key)) return null;
    final value = prefs.getDouble(key);
    if (value == null) return null;
    return TextScaleSetting.isAllowed(value) ? value : null;
  }

  /// スケール倍率を保存する（許可外の値は ArgumentError）。
  Future<void> saveScale(double scale) async {
    if (!TextScaleSetting.isAllowed(scale)) {
      throw ArgumentError.value(scale, 'scale', '許可されていない文字サイズ倍率');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, scale);
  }
}
