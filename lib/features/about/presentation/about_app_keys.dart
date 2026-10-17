import 'package:flutter/material.dart';

/// アプリについて画面の試練用Key一括管理。
///
/// 既存 AppKeys（core/testing/widget_keys.dart）は変更しない方針のため、
/// about feature 専用のKeyファイルとして分離する。
class AboutAppKeys {
  AboutAppKeys._();

  /// AboutScreen の Scaffold。
  static const Key aboutScreen = Key('screen_about');

  /// バージョン表示（v<version>）。
  static const Key versionLabel = Key('txt_about_version');

  /// OSSライセンス タイル。
  static const Key licenseTile = Key('tile_about_license');

  /// プライバシーポリシー タイル。
  static const Key privacyTile = Key('tile_about_privacy');

  /// 問い合わせ タイル。
  static const Key contactTile = Key('tile_about_contact');

  /// ダイアログ内のコピー ボタン。
  static const Key copyButton = Key('btn_about_copy');

  /// 書庫 AppBar など設定導線側の入口。
  static const Key entryFromSettings = Key('btn_about_settings');
}
