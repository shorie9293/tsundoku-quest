import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/goals/data/daily_reading_goal_provider.dart';
import 'package:tsundoku_quest/features/goals/data/daily_reading_goal_repository.dart';
import 'package:tsundoku_quest/features/goals/data/reading_goal_provider.dart';
import 'package:tsundoku_quest/features/goals/data/reading_goal_repository.dart';
import 'package:tsundoku_quest/features/goals/domain/daily_reading_goal.dart';
import 'package:tsundoku_quest/features/goals/presentation/daily_reading_goal_screen.dart';
import 'package:tsundoku_quest/features/goals/presentation/reading_goal_screen.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

/// 全角数字・全角カンマ入力の画面回帰試練（改善提案#215）。
///
/// 日本語IMEで「３０」と入力すると int.tryParse が null を返し、
/// 目標が黙って 0（＝未設定）に落ちていた欠陥の再発防止。
void main() {
  group('1日の読書時間目標（DailyReadingGoalScreen）', () {
    Widget wrapDaily(DailyReadingGoalRepository repo) => ProviderScope(
          overrides: [
            dailyReadingGoalRepositoryProvider.overrideWithValue(repo)
          ],
          child: MaterialApp(
            home: DailyReadingGoalScreen(
              sessionsOverride: const [],
              nowOverride: DateTime(2026, 10, 9, 12, 0),
            ),
          ),
        );

    Future<void> pumpDaily(WidgetTester tester, Widget widget) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
    }

    testWidgets('全角３０を入力して保存すると30分として永続化される', (tester) async {
      final repo = InMemoryDailyReadingGoalRepository();
      await pumpDaily(tester, wrapDaily(repo));

      await tester.enterText(
        find.byKey(AppKeys.dailyReadingGoalTargetField),
        '３０',
      );
      await tester.tap(find.byKey(AppKeys.dailyReadingGoalSaveButton));
      await tester.pumpAndSettle();

      expect(repo.current.targetMinutes, 30);
      final label = tester.widget<Text>(
        find.byKey(AppKeys.dailyReadingGoalTodayLabel),
      );
      expect(label.data, '今日 0 / 30分');
    });

    testWidgets('全角カンマ区切り１，０を入力すると10分として永続化される', (tester) async {
      final repo = InMemoryDailyReadingGoalRepository();
      await pumpDaily(tester, wrapDaily(repo));

      await tester.enterText(
        find.byKey(AppKeys.dailyReadingGoalTargetField),
        '１，０',
      );
      await tester.tap(find.byKey(AppKeys.dailyReadingGoalSaveButton));
      await tester.pumpAndSettle();

      expect(repo.current.targetMinutes, 10);
    });

    testWidgets('全角数字に単位が混ざった３０分は保存せず既存目標を変えない', (tester) async {
      final repo = InMemoryDailyReadingGoalRepository(
        initial: const DailyReadingGoal(targetMinutes: 30),
      );
      await pumpDaily(tester, wrapDaily(repo));

      await tester.enterText(
        find.byKey(AppKeys.dailyReadingGoalTargetField),
        '４５分',
      );
      await tester.tap(find.byKey(AppKeys.dailyReadingGoalSaveButton));
      await tester.pumpAndSettle();

      expect(repo.current.targetMinutes, 30);
      expect(find.text('分数を数値で入力してください'), findsOneWidget);
    });

    testWidgets('全角０を入力すると従来通り目標解除になる', (tester) async {
      final repo = InMemoryDailyReadingGoalRepository(
        initial: const DailyReadingGoal(targetMinutes: 30),
      );
      await pumpDaily(tester, wrapDaily(repo));

      await tester.enterText(
        find.byKey(AppKeys.dailyReadingGoalTargetField),
        '０',
      );
      await tester.tap(find.byKey(AppKeys.dailyReadingGoalSaveButton));
      await tester.pumpAndSettle();

      expect(repo.current.targetMinutes, 0);
      expect(find.byKey(AppKeys.dailyReadingGoalEmpty), findsOneWidget);
    });
  });

  group('読書目標（ReadingGoalScreen）', () {
    Widget wrapGoal(ReadingGoalRepository repo) => ProviderScope(
          overrides: [
            readingGoalRepositoryProvider.overrideWithValue(repo),
            bookDataProvider.overrideWith((ref) => _FakeBookData()),
          ],
          child: const MaterialApp(home: ReadingGoalScreen()),
        );

    testWidgets('月間・年間とも全角数字で保存すると冊数として永続化される', (tester) async {
      final repo = InMemoryReadingGoalRepository();
      await tester.pumpWidget(wrapGoal(repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(AppKeys.readingGoalMonthlyField),
        '２',
      );
      await tester.enterText(
        find.byKey(AppKeys.readingGoalYearlyField),
        '２４',
      );
      await tester.tap(find.byKey(AppKeys.readingGoalSaveButton));
      await tester.pumpAndSettle();

      final saved = await repo.load();
      expect(saved.monthlyTarget, 2);
      expect(saved.yearlyTarget, 24);
    });

    testWidgets('全角カンマ入りの１，２を入力すると12冊として永続化される', (tester) async {
      final repo = InMemoryReadingGoalRepository();
      await tester.pumpWidget(wrapGoal(repo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(AppKeys.readingGoalMonthlyField),
        '１，２',
      );
      await tester.tap(find.byKey(AppKeys.readingGoalSaveButton));
      await tester.pumpAndSettle();

      expect((await repo.load()).monthlyTarget, 12);
    });
  });
}

/// 目標画面は読了冊数を BookDataProvider から取るため、空の状態を注入する。
class _FakeBookData extends BookDataNotifier {
  _FakeBookData() : super(null);

  @override
  BookDataState get state => const BookDataState(
        userBooks: <UserBook>[],
        isLoading: false,
      );
}
