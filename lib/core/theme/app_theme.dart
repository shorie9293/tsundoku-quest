import 'package:flutter/material.dart';

/// ツンドクエスト ダークテーマ
///
/// Next.js の Tailwind CSS（stone-950基調 + dungeon色）からの移植
class AppTheme {
  AppTheme._();

  // ━━━ 色定義 ━━━
  // stone-950: 背景
  static const Color background = Color(0xFF0C0A09);
  // stone-900: カード背景
  static const Color cardBackground = Color(0xFF1C1917);
  // stone-800: ボーダー
  static const Color border = Color(0xFF292524);
  // stone-100: 本文
  static const Color textPrimary = Color(0xFFF5F5F4);
  // stone-500: 補足テキスト
  static const Color textSecondary = Color(0xFF78716C);
  // dungeon-600: アクセント
  static const Color accent = Color(0xFF7C3AED);
  // dungeon-400: アクティブ
  static const Color active = Color(0xFFA78BFA);
  // emerald-400: 進捗バー
  static const Color progress = Color(0xFF34D399);
  // amber-400: カレンダー今日
  static const Color calendarToday = Color(0xFFFBBF24);
  // gold-500: バッジ
  static const Color badge = Color(0xFFEAB308);

  // 状態色
  static const Color tsundokuColor = Color(0xFFF59E0B); // amber-500
  static const Color readingColor = Color(0xFF3B82F6); // blue-500
  static const Color completedColor = Color(0xFF10B981); // emerald-500

  // ━━━ テーマデータ ━━━
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: background,
        primary: accent,
        secondary: active,
        tertiary: progress,
        onSurface: textPrimary,
        onPrimary: Colors.white,
        outline: border,
      ),
      // テキストテーマ
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary),
        displayMedium: TextStyle(color: textPrimary),
        displaySmall: TextStyle(color: textPrimary),
        headlineLarge: TextStyle(color: textPrimary),
        headlineMedium: TextStyle(color: textPrimary),
        headlineSmall: TextStyle(color: textPrimary),
        titleLarge: TextStyle(color: textPrimary),
        titleMedium: TextStyle(color: textPrimary),
        titleSmall: TextStyle(color: textSecondary),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
        labelLarge: TextStyle(color: textPrimary),
        labelMedium: TextStyle(color: textSecondary),
        labelSmall: TextStyle(color: textSecondary),
      ),
      // AppBarテーマ
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      // ボトムナビゲーションテーマ
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: active,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      // カードテーマ
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      // 入力フィールドテーマ
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      // ボタンテーマ
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      // タブテーマ
      tabBarTheme: const TabBarThemeData(
        labelColor: active,
        unselectedLabelColor: textSecondary,
        indicatorColor: accent,
      ),
      // ダイアログテーマ
      dialogTheme: DialogThemeData(
        backgroundColor: cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      // スナックバーテーマ
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardBackground,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
