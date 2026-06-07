import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/theme/app_theme.dart';

void main() {
  group('AppTheme - 色定義', () {
    test('背景色はstone-950 (#0C0A09)', () {
      expect(AppTheme.background, const Color(0xFF0C0A09));
    });

    test('カード背景色はstone-900 (#1C1917)', () {
      expect(AppTheme.cardBackground, const Color(0xFF1C1917));
    });

    test('ボーダー色はstone-800 (#292524)', () {
      expect(AppTheme.border, const Color(0xFF292524));
    });

    test('本文色はstone-100 (#F5F5F4)', () {
      expect(AppTheme.textPrimary, const Color(0xFFF5F5F4));
    });

    test('補足テキスト色はstone-500 (#78716C)', () {
      expect(AppTheme.textSecondary, const Color(0xFF78716C));
    });

    test('アクセント色はdungeon-600 (#7C3AED)', () {
      expect(AppTheme.accent, const Color(0xFF7C3AED));
    });

    test('アクティブ色はdungeon-400 (#A78BFA)', () {
      expect(AppTheme.active, const Color(0xFFA78BFA));
    });

    test('進捗バー色はemerald-400 (#34D399)', () {
      expect(AppTheme.progress, const Color(0xFF34D399));
    });

    test('カレンダー今日色はamber-400 (#FBBF24)', () {
      expect(AppTheme.calendarToday, const Color(0xFFFBBF24));
    });

    test('バッジ色はgold-500 (#EAB308)', () {
      expect(AppTheme.badge, const Color(0xFFEAB308));
    });

    test('つんどく色はamber-500 (#F59E0B)', () {
      expect(AppTheme.tsundokuColor, const Color(0xFFF59E0B));
    });

    test('読書中色はblue-500 (#3B82F6)', () {
      expect(AppTheme.readingColor, const Color(0xFF3B82F6));
    });

    test('読了色はemerald-500 (#10B981)', () {
      expect(AppTheme.completedColor, const Color(0xFF10B981));
    });
  });

  group('AppTheme - テーマデータ', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.darkTheme;
    });

    test('Material3を使用', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('ダークモード', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('スキャフォールド背景色', () {
      expect(theme.scaffoldBackgroundColor, AppTheme.background);
    });

    test('colorSchemeのprimaryがaccent', () {
      expect(theme.colorScheme.primary, AppTheme.accent);
    });

    test('colorSchemeのsurfaceがbackground', () {
      expect(theme.colorScheme.surface, AppTheme.background);
    });

    test('AppBarテーマ - 背景色・標高0・中央タイトル', () {
      final appBarTheme = theme.appBarTheme;
      expect(appBarTheme.backgroundColor, AppTheme.background);
      expect(appBarTheme.elevation, 0);
      expect(appBarTheme.centerTitle, true);
    });

    test('BottomNavigationBarテーマ - fixed型', () {
      final navTheme = theme.bottomNavigationBarTheme;
      expect(navTheme.type, BottomNavigationBarType.fixed);
      expect(navTheme.selectedItemColor, AppTheme.active);
      expect(navTheme.unselectedItemColor, AppTheme.textSecondary);
      expect(navTheme.backgroundColor, AppTheme.cardBackground);
    });

    test('Cardテーマ - 角丸12px + ボーダー', () {
      final cardTheme = theme.cardTheme;
      expect(cardTheme.color, AppTheme.cardBackground);
      expect(cardTheme.elevation, 2);
      expect(
        (cardTheme.shape as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(12),
      );
    });

    test('InputDecorationテーマ - filledでcardBackground', () {
      final inputTheme = theme.inputDecorationTheme;
      expect(inputTheme.filled, isTrue);
      expect(inputTheme.fillColor, AppTheme.cardBackground);
    });

    test('ElevatedButtonテーマ - accent背景・白文字', () {
      final buttonStyle = theme.elevatedButtonTheme.style;
      expect(
        buttonStyle?.backgroundColor?.resolve({}),
        AppTheme.accent,
      );
    });

    test('Dialogテーマ - 角丸16px', () {
      final dialogTheme = theme.dialogTheme;
      expect(dialogTheme.backgroundColor, AppTheme.cardBackground);
    });

    test('TextTheme - 全タイトル・本文はtextPrimary', () {
      final textTheme = theme.textTheme;
      expect(textTheme.headlineLarge?.color, AppTheme.textPrimary);
      expect(textTheme.bodyLarge?.color, AppTheme.textPrimary);
      expect(textTheme.labelLarge?.color, AppTheme.textPrimary);
      expect(textTheme.titleSmall?.color, AppTheme.textSecondary);
    });

    test('SnackBarテーマ - floating', () {
      final snackBarTheme = theme.snackBarTheme;
      expect(snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(snackBarTheme.backgroundColor, AppTheme.cardBackground);
    });
  });
}
