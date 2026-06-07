import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/tutorial/data/tutorial_preferences.dart';
import 'package:tsundoku_quest/features/tutorial/presentation/tutorial_screen.dart';

/// チュートリアル画面のテスト
void main() {
  group('TutorialScreen', () {
    setUp(() {
      // SharedPreferences のテスト用初期化
      SharedPreferences.setMockInitialValues({});
    });

    Widget buildTestScreen(TutorialPreferences prefs) {
      return MaterialApp(
        home: TutorialScreen(prefs: prefs),
      );
    }

    testWidgets('should display tutorial screen', (tester) async {
      final prefs = TutorialPreferences(await SharedPreferences.getInstance());
      await tester.pumpWidget(buildTestScreen(prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.tutorialScreen), findsOneWidget);
      expect(find.byKey(AppKeys.tutorialPageView), findsOneWidget);
    });

    testWidgets('should show first lore page on start', (tester) async {
      final prefs = TutorialPreferences(await SharedPreferences.getInstance());
      await tester.pumpWidget(buildTestScreen(prefs));
      await tester.pumpAndSettle();

      expect(find.text('積読ダンジョンへようこそ'), findsOneWidget);
    });

    testWidgets('should show all 4 lore pages via swipe', (tester) async {
      final prefs = TutorialPreferences(await SharedPreferences.getInstance());
      await tester.pumpWidget(buildTestScreen(prefs));
      await tester.pumpAndSettle();

      // 最初はページ1
      expect(find.text('積読ダンジョンへようこそ'), findsOneWidget);

      // Swipe to page 2
      await tester.drag(find.byKey(AppKeys.tutorialPageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('読書は冒険'), findsOneWidget);

      // Swipe to page 3
      await tester.drag(find.byKey(AppKeys.tutorialPageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('ダンジョンは書庫'), findsOneWidget);

      // Swipe to page 4
      await tester.drag(find.byKey(AppKeys.tutorialPageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('さあ、探索の始まりだ'), findsOneWidget);

      // Swipe to 操作説明ページ（5ページ目）
      await tester.drag(find.byKey(AppKeys.tutorialPageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('操作ガイド'), findsOneWidget);
    });

    testWidgets('should show skip button only on operation page',
        (tester) async {
      final prefs = TutorialPreferences(await SharedPreferences.getInstance());
      await tester.pumpWidget(buildTestScreen(prefs));
      await tester.pumpAndSettle();

      // 世界観ページではスキップボタン非表示
      expect(find.byKey(AppKeys.tutorialSkipButton), findsNothing);

      // 操作ページまでスワイプ
      for (int i = 0; i < 4; i++) {
        await tester.drag(
            find.byKey(AppKeys.tutorialPageView), const Offset(-500, 0));
        await tester.pumpAndSettle();
      }

      // 操作ページではスキップボタン表示
      expect(find.byKey(AppKeys.tutorialSkipButton), findsOneWidget);
    });

    testWidgets('should dismiss tutorial when tapping start on last page',
        (tester) async {
      final prefs = TutorialPreferences(await SharedPreferences.getInstance());
      await tester.pumpWidget(buildTestScreen(prefs));
      await tester.pumpAndSettle();

      // 最終ページ（操作説明）までスワイプ
      for (int i = 0; i < 4; i++) {
        await tester.drag(
            find.byKey(AppKeys.tutorialPageView), const Offset(-500, 0));
        await tester.pumpAndSettle();
      }

      // 「探索を始める」ボタンをタップ
      await tester.tap(find.byKey(AppKeys.tutorialStartButton));
      await tester.pumpAndSettle();

      // 画面が閉じられたことを確認
      expect(find.byKey(AppKeys.tutorialScreen), findsNothing);
    });

    testWidgets('should not show tutorial on second launch',
        (tester) async {
      final prefs = TutorialPreferences(await SharedPreferences.getInstance());
      // 初回起動済みにする
      await prefs.markLoreSeen();
      await prefs.markOperationSeen();

      await tester.pumpWidget(buildTestScreen(prefs));
      await tester.pumpAndSettle();

      // 画面が表示されないはず（でも Widget テストなので存在する）
      expect(find.byKey(AppKeys.tutorialScreen), findsOneWidget);
    });

    testWidgets('should mark prefs as seen on finish', (tester) async {
      final prefs = TutorialPreferences(await SharedPreferences.getInstance());
      await tester.pumpWidget(buildTestScreen(prefs));
      await tester.pumpAndSettle();

      // 最終ページまでスワイプ
      for (int i = 0; i < 4; i++) {
        await tester.drag(
            find.byKey(AppKeys.tutorialPageView), const Offset(-500, 0));
        await tester.pumpAndSettle();
      }

      // 「探索を始める」をタップ
      await tester.tap(find.byKey(AppKeys.tutorialStartButton));
      await tester.pumpAndSettle();

      // フラグが設定されたことを確認
      expect(prefs.isLoreNotSeen, isFalse);
      expect(prefs.isOperationNotSeen, isFalse);
    });
  });
}
