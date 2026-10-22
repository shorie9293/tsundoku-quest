// コード適応神書 原則③（Semantics体系）— 足跡画面の試練
//
// SemanticHelper で付与した identifier が、ADB uiautomator の content-desc /
// TalkBack の読み上げ対象として露出していることを検証する。
// 併せて既存 AppKeys が残存していること（既存試練を壊していないこと）を確認する。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/app_router.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('hive_history_semantics_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// 足跡画面を /history タブ経由で描画する（app_router_test と同じ作法）
  Future<void> pumpHistory(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: AppRouter.createRouter(isSignedIn: () => true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.tabHistory));
    await tester.pumpAndSettle();
  }

  testWidgets('AppBar の導線に identifier と日本語ラベルが付与される', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHistory(tester);

    expect(find.bySemanticsIdentifier('btn_history_share_card'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_history_session_log'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_history_daily_goal'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_history_badges'), findsOneWidget);

    final share = find.bySemanticsIdentifier('btn_history_share_card');
    expect(tester.getSemantics(share).label, contains('読了カードを共有'));

    handle.dispose();
  });

  testWidgets('統計カードに identifier が付与される', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHistory(tester);

    expect(find.bySemanticsIdentifier('btn_history_stat_books'), findsOneWidget);
    expect(
        find.bySemanticsIdentifier('btn_history_stat_completed'), findsOneWidget);
    expect(
        find.bySemanticsIdentifier('card_history_stat_minutes'), findsOneWidget);
    expect(find.bySemanticsIdentifier('card_history_stat_pages'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('既存の AppKeys は残存する（既存試練を壊していない）', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHistory(tester);

    expect(find.byKey(AppKeys.historyScreen), findsOneWidget);
    expect(find.byKey(AppKeys.historyShareButton), findsOneWidget);
    expect(find.byKey(AppKeys.readingSessionLogButton), findsOneWidget);
    expect(find.byKey(AppKeys.dailyReadingGoalButton), findsOneWidget);
    expect(find.byKey(AppKeys.badgeCollectionButton), findsOneWidget);
    expect(find.byKey(AppKeys.monthlyStatsGrid), findsOneWidget);

    handle.dispose();
  });
}
