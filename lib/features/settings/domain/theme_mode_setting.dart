import 'package:flutter/material.dart';

/// テーマモード設定（ライト/ダーク/システム）
///
/// SharedPreferences には [storageKey] を文字列として保存する。
/// 未保存・不正値は [ThemeModeSetting.system] として扱う。
enum ThemeModeSetting {
  light('light', 'ライト', Icons.light_mode_outlined),
  dark('dark', 'ダーク', Icons.dark_mode_outlined),
  system('system', 'システム', Icons.brightness_auto_outlined);

  const ThemeModeSetting(this.storageKey, this.label, this.icon);

  /// 保存用キー（'light' / 'dark' / 'system'）
  final String storageKey;

  /// UI表示用ラベル
  final String label;

  /// UI表示用アイコン
  final IconData icon;

  /// 保存キーに対応する設定。
  /// 'light'/'dark'/'system' 以外および null は [ThemeModeSetting.system]。
  static ThemeModeSetting fromStorageKey(String? key) {
    for (final mode in values) {
      if (mode.storageKey == key) return mode;
    }
    return system;
  }

  /// 巡回: light→dark→system→light
  ThemeModeSetting get next => switch (this) {
        ThemeModeSetting.light => ThemeModeSetting.dark,
        ThemeModeSetting.dark => ThemeModeSetting.system,
        ThemeModeSetting.system => ThemeModeSetting.light,
      };

  /// Flutter の [ThemeMode] へ変換する。
  ThemeMode toThemeMode() => switch (this) {
        ThemeModeSetting.light => ThemeMode.light,
        ThemeModeSetting.dark => ThemeMode.dark,
        ThemeModeSetting.system => ThemeMode.system,
      };
}
