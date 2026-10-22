// コード適応神書 原則③（Semantics体系）— 日次読書目標画面の試練
//
// 保存/解除ボタン・プリセットチップ・数値入力欄・進捗カードに付与した
// identifier が露出していることを検証し、既存 AppKeys と既存挙動
// （チップ押下で目標が保存される）が壊れていないことも確認する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/goals/data/daily_reading_goal_provider.dart';
import 'package:tsundoku_quest/features/goals/data/daily_reading_goal_repository.dart';
import 'package:tsundoku_quest/features/goals/domain/daily_reading_goal.dart';
import 'package:tsundoku_quest/features/goals/presentation/daily_reading_goal_screen.dart';

final DateTime _now = DateTime(2026, 10, 9, 12, 0);

ReadingSession _session(String id, DateTime date, int minutes) => ReadingSession(
      id: id,
      userBookId: 'ub-$id',
      startedAt: date.toIso8601String(),
      startPage: 1,
      endPage: 10,
      durationMinutes: minutes,
      createdAt: date.toIso8601String(),
    );

Widget _wrap({
  required DailyReadingGoalRepository repo,
  List<ReadingSession> sessions = const [],
}) {
  return ProviderScope(
    overrides: [
      dailyReadingGoalRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: DailyReadingGoalScreen(
        sessionsOverride: sessions,
        nowOverride: _now,
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  // 縦長画面の下方ウィジェット（入力欄・保存ボタン）も描画させる
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('進捗カード・ストリーク・7日チャートに identifier が付与される', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _wrap(repo: InMemoryDailyReadingGoalRepository()));

    expect(find.bySemanticsIdentifier('card_daily_goal_today'), findsOneWidget);
    expect(
        find.bySemanticsIdentifier('progress_daily_goal_today'), findsOneWidget);
    expect(find.bySemanticsIdentifier('card_daily_goal_streak'), findsOneWidget);
    expect(find.bySemanticsIdentifier('chart_daily_goal_seven_days'),
        findsOneWidget);

    handle.dispose();
  });

  testWidgets('プリセットチップ・数値入力欄・保存/解除ボタンに identifier が付与される',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _wrap(repo: InMemoryDailyReadingGoalRepository()));

    expect(find.bySemanticsIdentifier('btn_daily_goal_preset_15'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_daily_goal_preset_30'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_daily_goal_preset_90'), findsOneWidget);
    expect(find.bySemanticsIdentifier('txt_daily_goal_target'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_daily_goal_save'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn_daily_goal_clear'), findsOneWidget);

    expect(tester.getSemantics(find.bySemanticsIdentifier('btn_daily_goal_save')).label,
        contains('保存'));

    handle.dispose();
  });

  testWidgets('既存の AppKeys と既存挙動は維持される', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = InMemoryDailyReadingGoalRepository();
    await _pump(tester, _wrap(repo: repo));

    expect(find.byKey(AppKeys.dailyReadingGoalScreen), findsOneWidget);
    expect(find.byKey(AppKeys.dailyReadingGoalTodayCard), findsOneWidget);
    expect(find.byKey(AppKeys.dailyReadingGoalTodayLabel), findsOneWidget);
    expect(find.byKey(AppKeys.dailyReadingGoalEmpty), findsOneWidget);
    expect(find.byKey(AppKeys.dailyReadingGoalSevenDayRow), findsOneWidget);
    expect(find.byKey(AppKeys.dailyReadingGoalTargetField), findsOneWidget);
    expect(find.byKey(AppKeys.dailyReadingGoalSaveButton), findsOneWidget);
    expect(find.byKey(AppKeys.dailyReadingGoalClearButton), findsOneWidget);
    expect(find.byKey(AppKeys.dailyReadingGoalChip(30)), findsOneWidget);

    // 既存挙動: チップ押下で目標が保存される
    await tester.tap(find.byKey(AppKeys.dailyReadingGoalChip(30)));
    await tester.pumpAndSettle();
    expect(repo.current.targetMinutes, 30);

    handle.dispose();
  });

  testWidgets('達成時も identifier は1つずつ露出する（重複しない）', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = InMemoryDailyReadingGoalRepository(
      initial: const DailyReadingGoal(targetMinutes: 30),
    );
    await _pump(
      tester,
      _wrap(
        repo: repo,
        sessions: [_session('a', DateTime(2026, 10, 9, 20, 0), 40)],
      ),
    );

    expect(find.text('🏆 達成！'), findsOneWidget);
    expect(find.bySemanticsIdentifier('card_daily_goal_today'), findsOneWidget);
    expect(find.bySemanticsIdentifier('card_daily_goal_streak'), findsOneWidget);

    handle.dispose();
  });
}
