import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/adventurer_stats.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/adventurer_header.dart';
import 'package:tsundoku_quest/shared/providers/adventurer_provider.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';

Widget testHeader({
  int level = 3,
  int xp = 150,
  int xpToNext = 400,
  String title = 'Explorer',
  int totalBooksRegistered = 0,
  int totalBooksCompleted = 0,
  int totalReadingMinutes = 0,
  int totalPagesRead = 0,
}) {
  return ProviderScope(
    overrides: [
      adventurerProvider.overrideWith((ref) {
        final notifier = AdventurerNotifier();
        notifier.state = AdventurerStats(
          level: level,
          xp: xp,
          xpToNextLevel: xpToNext,
          title: title,
          totalBooksRegistered: totalBooksRegistered,
          totalBooksCompleted: totalBooksCompleted,
          totalReadingMinutes: totalReadingMinutes,
          totalPagesRead: totalPagesRead,
          currentStreak: 0,
          longestStreak: 0,
          readingDates: [],
        );
        return notifier;
      }),
    ],
    child: const MaterialApp(
      home: Scaffold(body: AdventurerHeader()),
    ),
  );
}

void main() {
  group('AdventurerHeader', () {
    testWidgets('should display XpBar inside', (tester) async {
      await tester.pumpWidget(testHeader());

      // XpBar is rendered inside AdventurerHeader
      expect(find.byKey(AppKeys.xpBar), findsOneWidget);
    });

    testWidgets('should have AppKey set', (tester) async {
      await tester.pumpWidget(testHeader());

      expect(find.byKey(AppKeys.adventurerHeader), findsOneWidget);
    });

    testWidgets('should show greeting text', (tester) async {
      await tester.pumpWidget(testHeader());

      expect(find.text('冒険者'), findsOneWidget);
    });

    testWidgets('should display totalReadingMinutes when non-zero', (tester) async {
      await tester.pumpWidget(testHeader(totalReadingMinutes: 120));

      expect(find.text('120分'), findsOneWidget);
    });

    testWidgets('should display totalPagesRead when non-zero', (tester) async {
      await tester.pumpWidget(testHeader(totalPagesRead: 350));

      expect(find.text('350P'), findsOneWidget);
    });

    testWidgets('should display totalBooksRegistered when non-zero', (tester) async {
      await tester.pumpWidget(testHeader(totalBooksRegistered: 10));

      expect(find.text('10冊'), findsOneWidget);
    });

    testWidgets('should display totalBooksCompleted when non-zero', (tester) async {
      await tester.pumpWidget(testHeader(totalBooksCompleted: 5));

      expect(find.text('5冊'), findsOneWidget);
    });
  });
}
