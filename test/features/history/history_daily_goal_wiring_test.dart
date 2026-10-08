import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/history/data/reading_habit_provider.dart';
import 'package:tsundoku_quest/features/history/presentation/history_screen.dart';
import '../../test_helpers.dart';

void main() {
  setUpAll(() {
    initTestHive();
  });
  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('履歴AppBarの目標ボタンから日次読書目標画面が開く', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 実ネットワークへ触れないようセッション供給を空に固定する
          readingHabitSessionsProvider
              .overrideWith((ref) => <ReadingSession>[]),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.dailyReadingGoalButton), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.dailyReadingGoalButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.dailyReadingGoalScreen), findsOneWidget);
  });
}
