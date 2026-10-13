import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/badges/data/badge_provider.dart';
import 'package:tsundoku_quest/features/badges/data/badge_record_repository.dart';
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

  testWidgets('履歴AppBarのバッジボタンから実績バッジ画面が開く', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 実ネットワークへ触れないようセッション供給を空に固定する
          readingHabitSessionsProvider
              .overrideWith((ref) => <ReadingSession>[]),
          // testWidgets(fake async)では実Hive IOが完了しないため
          // インメモリ実装へ差し替える（daily_goal_screen_test と同型）
          badgeRecordRepositoryProvider
              .overrideWithValue(InMemoryBadgeRecordRepository()),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.badgeCollectionButton), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.badgeCollectionButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.badgeCollectionScreen), findsOneWidget);
  });
}