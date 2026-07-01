import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/history/presentation/history_screen.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';

Widget testHistoryScreen() {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const HistoryScreen(),
    ),
  );
}

Widget testHistoryScreenWithTrophies(List<WarTrophy> trophies) {
  final trophyNotifier = WarTrophyNotifier(null);
  // Manually add trophies
  for (final t in trophies) {
    trophyNotifier.addTrophy(t);
  }
  return ProviderScope(
    overrides: [
      warTrophyProvider.overrideWith((ref) => trophyNotifier),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const HistoryScreen(),
    ),
  );
}

void main() {
  group('HistoryScreen', () {
    testWidgets('should display app bar with title', (tester) async {
      await tester.pumpWidget(testHistoryScreen());

      expect(find.text('📊 足跡'), findsOneWidget);
    });

    testWidgets('should display monthly stats grid', (tester) async {
      await tester.pumpWidget(testHistoryScreen());

      expect(find.byKey(AppKeys.monthlyStatsGrid), findsOneWidget);
    });

    testWidgets('should display reading calendar widget', (tester) async {
      await tester.pumpWidget(testHistoryScreen());
      // カレンダーWidgetまでスクロールして表示
      await tester.scrollUntilVisible(
        find.byKey(AppKeys.readingCalendar),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // ReadingCalendarWidget が AppKeys.readingCalendar で存在する
      expect(find.byKey(AppKeys.readingCalendar), findsOneWidget);
    });

    testWidgets('should display calendar title', (tester) async {
      await tester.pumpWidget(testHistoryScreen());
      // カレンダーのタイトルまでスクロール
      await tester.scrollUntilVisible(
        find.text('📅 読書カレンダー'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('📅 読書カレンダー'), findsOneWidget);
    });

    // ━━━ 読書感想・メモ表示 ━━━

    testWidgets('should display reading notes section title', (tester) async {
      await tester.pumpWidget(testHistoryScreen());

      await tester.scrollUntilVisible(
        find.byKey(AppKeys.readingNotesSection),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(AppKeys.readingNotesSection), findsOneWidget);
    });

    testWidgets('should display empty CTA when no notes exist', (tester) async {
      await tester.pumpWidget(testHistoryScreen());

      await tester.scrollUntilVisible(
        find.byKey(AppKeys.readingNotesEmpty),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(AppKeys.readingNotesEmpty), findsOneWidget);
    });

    testWidgets('should display empty CTA text when no notes exist',
        (tester) async {
      await tester.pumpWidget(testHistoryScreen());

      await tester.scrollUntilVisible(
        find.text('感想を書いてみよう'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('感想を書いてみよう'), findsOneWidget);
    });

    testWidgets('should display war trophy learnings when available',
        (tester) async {
      const trophies = [
        WarTrophy(
          id: 'trophy-1',
          userBookId: 'book-1',
          userId: 'user-1',
          learnings: ['深い学び1', '気づきがあった', '実践したい'],
          action: '毎日読書する',
          favoriteQuote: '本の中の名言',
          createdAt: '2026-06-30T12:00:00.000Z',
        ),
      ];

      await tester.pumpWidget(testHistoryScreenWithTrophies(trophies));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('深い学び1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('深い学び1'), findsOneWidget);
      expect(find.text('気づきがあった'), findsOneWidget);
      expect(find.text('実践したい'), findsOneWidget);
    });

    testWidgets('should display trophy list with correct key',
        (tester) async {
      const trophies = [
        WarTrophy(
          id: 'trophy-1',
          userBookId: 'book-1',
          userId: 'user-1',
          learnings: ['学び1'],
          action: '行動',
          createdAt: '2026-06-30T12:00:00.000Z',
        ),
      ];

      await tester.pumpWidget(testHistoryScreenWithTrophies(trophies));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(AppKeys.readingNotesList),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(AppKeys.readingNotesList), findsOneWidget);
    });
  });
}
