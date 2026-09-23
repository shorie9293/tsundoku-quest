import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/features/settings/domain/theme_mode_setting.dart';

/// テーマモード設定のリポジトリ
///
/// SharedPreferences にテーマモードの storageKey を保存・復元する。
class ThemeModeRepository {
  static const String key = 'tsundoku_theme_mode';

  const ThemeModeRepository();

  /// 保存されたテーマモードを読み込む。
  /// 未保存、または不正値の場合は null（=system 扱い）。
  Future<ThemeModeSetting?> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(key)) return null;
    final value = prefs.getString(key);
    if (value == null) return null;
    for (final mode in ThemeModeSetting.values) {
      if (mode.storageKey == value) return mode;
    }
    return null;
  }

  /// テーマモードを保存する。
  Future<void> saveThemeMode(ThemeModeSetting mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, mode.storageKey);
  }
}
