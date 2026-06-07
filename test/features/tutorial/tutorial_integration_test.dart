import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/tutorial/data/tutorial_preferences.dart';
import 'package:tsundoku_quest/features/tutorial/presentation/tutorial_screen.dart';

/// 実アプリの Navigator ネスト構造を再現する統合テスト。
///
/// MaterialApp.router + GoRouter では:
/// - builder コンテキストは Navigator の外側（Navigator.of が使えない）
/// - AppScaffold は GoRouter の Navigator 内部に配置される
/// - rootNavigator: true でルート Navigator にアクセスする
///
/// このテストでは Navigator 内に _TestAppScaffold を配置し、
/// AppScaffold と同じ Navigator コンテキストでチュートリアルを表示する。
void main() {
  group('TutorialScreen integration (Navigator context)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
        'should dismiss when tapping start on last page (Navigator context)',
        (tester) async {
      final prefs = TutorialPreferences(await SharedPreferences.getInstance());

      // MaterialApp の Navigator 内に _TestAppScaffold を配置。
      // AppScaffold が GoRouter の Navigator 内にあるのと同じ構造。
      await tester.pumpWidget(
        MaterialApp(
          home: _TestAppScaffold(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle();

      // チュートリアルが表示されていることを確認
      expect(find.byKey(AppKeys.tutorialScreen), findsOneWidget);

      // 最終ページまでスワイプ
      for (int i = 0; i < 4; i++) {
        await tester.drag(
            find.byKey(AppKeys.tutorialPageView), const Offset(-500, 0));
        await tester.pumpAndSettle();
      }

      // 「探索を始める」ボタンが表示されていることを確認
      expect(find.text('探索を始める'), findsOneWidget);

      // タップ
      await tester.tap(find.byKey(AppKeys.tutorialStartButton));
      await tester.pumpAndSettle();

      // 画面が閉じられたことを確認
      expect(find.byKey(AppKeys.tutorialScreen), findsNothing);

      // チュートリアル完了フラグが設定されたことを確認
      expect(prefs.isLoreNotSeen, isFalse);
      expect(prefs.isOperationNotSeen, isFalse);
    });

    testWidgets('should not show tutorial on second launch', (tester) async {
      final prefs = TutorialPreferences(await SharedPreferences.getInstance());
      // 初回起動済みにする
      await prefs.markLoreSeen();
      await prefs.markOperationSeen();

      await tester.pumpWidget(
        MaterialApp(
          home: _TestAppScaffold(prefs: prefs),
        ),
      );

      await tester.pumpAndSettle();

      // チュートリアルが表示されないことを確認
      expect(find.byKey(AppKeys.tutorialScreen), findsNothing);
    });
  });
}

/// AppScaffold と同じ Navigator 内コンテキストを持つテスト用ラッパー。
/// initShowTutorialIfNeeded を初回フレーム後に実行する。
class _TestAppScaffold extends StatefulWidget {
  final TutorialPreferences prefs;
  const _TestAppScaffold({required this.prefs});

  @override
  State<_TestAppScaffold> createState() => _TestAppScaffoldState();
}

class _TestAppScaffoldState extends State<_TestAppScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTutorialIfNeeded();
    });
  }

  /// AppScaffold と同じロジック: Navigator.of(context, rootNavigator: true)
  Future<void> _showTutorialIfNeeded() async {
    try {
      if (!mounted || !widget.prefs.isFirstLaunch) return;

      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => TutorialScreen(prefs: widget.prefs),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ チュートリアル表示失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Home')),
    );
  }
}
