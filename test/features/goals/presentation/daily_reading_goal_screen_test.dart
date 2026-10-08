import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/goals/data/daily_reading_goal_provider.dart';
import 'package:tsundoku_quest/features/goals/data/daily_reading_goal_repository.dart';
import 'package:tsundoku_quest/features/goals/domain/daily_reading_goal.dart';
import 'package:tsundoku_quest/features/goals/presentation/daily_reading_goal_screen.dart';

/// 固定の「今日」（ローカル時刻）
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
  DateTime? now,
}) {
  return ProviderScope(
    overrides: [
      dailyReadingGoalRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: DailyReadingGoalScreen(
        sessionsOverride: sessions,
        nowOverride: now ?? _now,
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  // 縦長画面の下方ウィジェットも描画されるようビューポートを広げる
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(widget);
}

void main() {
  testWidgets('未設定のときは空状態メッセージと「目標未設定」を表示する', (tester) async {
    await _pump(tester, _wrap(repo: InMemoryDailyReadingGoalRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.dailyReadingGoalEmpty), findsOneWidget);
    final label = tester.widget<Text>(
      find.byKey(AppKeys.dailyReadingGoalTodayLabel),
    );
    expect(label.data, '目標未設定');
  });

  testWidgets('目標30分・今日20分なら未達成で今日ラベルが 20 / 30分', (tester) async {
    final repo = InMemoryDailyReadingGoalRepository(
      initial: const DailyReadingGoal(targetMinutes: 30),
    );
    await _pump(tester, _wrap(
      repo: repo,
      sessions: [_session('a', DateTime(2026, 10, 9, 20, 0), 20)],
    ));
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(
      find.byKey(AppKeys.dailyReadingGoalTodayLabel),
    );
    expect(label.data, '今日 20 / 30分');
    expect(find.text('🏆 達成！'), findsNothing);
  });

  testWidgets('目標30分・今日40分なら達成しストリークが1になる', (tester) async {
    final repo = InMemoryDailyReadingGoalRepository(
      initial: const DailyReadingGoal(targetMinutes: 30),
    );
    await _pump(tester, _wrap(
      repo: repo,
      sessions: [_session('a', DateTime(2026, 10, 9, 20, 0), 40)],
    ));
    await tester.pumpAndSettle();

    expect(find.text('🏆 達成！'), findsOneWidget);
    final current = tester.widget<Text>(
      find.byKey(AppKeys.dailyReadingGoalStreakCurrent),
    );
    expect(current.data, '現在 1日');
  });

  testWidgets('直近7日行は常に7要素を表示する', (tester) async {
    await _pump(tester, _wrap(repo: InMemoryDailyReadingGoalRepository()));
    await tester.pumpAndSettle();

    final row = tester.widget<Row>(
      find.byKey(AppKeys.dailyReadingGoalSevenDayRow),
    );
    expect(row.children.length, 7);
  });

  testWidgets('最長ストリークは連続達成日から算出される', (tester) async {
    final repo = InMemoryDailyReadingGoalRepository(
      initial: const DailyReadingGoal(targetMinutes: 30),
    );
    // 10/5,10/6,10/7 連続達成 + 10/9 今日達成
    final sessions = [
      _session('a', DateTime(2026, 10, 5, 10, 0), 40),
      _session('b', DateTime(2026, 10, 6, 10, 0), 40),
      _session('c', DateTime(2026, 10, 7, 10, 0), 40),
      _session('d', DateTime(2026, 10, 9, 10, 0), 40),
    ];
    await _pump(tester, _wrap(repo: repo, sessions: sessions));
    await tester.pumpAndSettle();

    final longest = tester.widget<Text>(
      find.byKey(AppKeys.dailyReadingGoalStreakLongest),
    );
    expect(longest.data, '最長 3日');
  });

  testWidgets('プリセットチップをタップすると目標が保存される', (tester) async {
    final repo = InMemoryDailyReadingGoalRepository();
    await _pump(tester, _wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.dailyReadingGoalChip(30)));
    await tester.pumpAndSettle();

    expect(repo.current.targetMinutes, 30);
  });

  testWidgets('入力して保存するとリポジトリへ永続化される', (tester) async {
    final repo = InMemoryDailyReadingGoalRepository();
    await _pump(tester, _wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(AppKeys.dailyReadingGoalTargetField), '45');
    await tester.tap(find.byKey(AppKeys.dailyReadingGoalSaveButton));
    await tester.pumpAndSettle();

    expect(repo.current.targetMinutes, 45);
  });

  testWidgets('解除ボタンで目標が未設定に戻る', (tester) async {
    final repo = InMemoryDailyReadingGoalRepository(
      initial: const DailyReadingGoal(targetMinutes: 30),
    );
    await _pump(tester, _wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.dailyReadingGoalClearButton));
    await tester.pumpAndSettle();

    expect(repo.current.targetMinutes, 0);
    expect(find.byKey(AppKeys.dailyReadingGoalEmpty), findsOneWidget);
  });

  testWidgets('非数値入力は保存せず目標を変えない', (tester) async {
    final repo = InMemoryDailyReadingGoalRepository(
      initial: const DailyReadingGoal(targetMinutes: 30),
    );
    await _pump(tester, _wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(AppKeys.dailyReadingGoalTargetField),
      'たくさん',
    );
    await tester.tap(find.byKey(AppKeys.dailyReadingGoalSaveButton));
    await tester.pumpAndSettle();

    expect(repo.current.targetMinutes, 30);
  });

  testWidgets('今日未達成でも昨日まで達成ならストリークは途切れない', (tester) async {
    final repo = InMemoryDailyReadingGoalRepository(
      initial: const DailyReadingGoal(targetMinutes: 30),
    );
    // 10/8 達成・10/9 今日は5分のみ
    final sessions = [
      _session('a', DateTime(2026, 10, 8, 10, 0), 40),
      _session('b', DateTime(2026, 10, 9, 10, 0), 5),
    ];
    await _pump(tester, _wrap(repo: repo, sessions: sessions));
    await tester.pumpAndSettle();

    final current = tester.widget<Text>(
      find.byKey(AppKeys.dailyReadingGoalStreakCurrent),
    );
    expect(current.data, '現在 1日');
  });
}
