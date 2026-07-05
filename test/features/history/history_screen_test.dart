import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/history/presentation/history_screen.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/domain/models/adventurer_stats.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';
import 'package:tsundoku_quest/shared/providers/adventurer_provider.dart';
import 'package:hive/hive.dart';
import '../../test_helpers.dart';

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
  setUpAll(() {
    initTestHive();
  });
  tearDownAll(() async {
    await Hive.close();
  });

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
      await tester.scrollUntilVisible(
        find.byKey(AppKeys.readingCalendar),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(AppKeys.readingCalendar), findsOneWidget);
    });

    testWidgets('should display calendar title', (tester) async {
      await tester.pumpWidget(testHistoryScreen());
      await tester.scrollUntilVisible(
        find.text('📅 読書カレンダー'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('📅 読書カレンダー'), findsOneWidget);
    });

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

  group('HistoryScreen stat card tap navigation', () {
    UserBook testBook(String id, String title, BookStatus status) => UserBook(
          id: id,
          userId: 'user-1',
          bookId: 'book-$id',
          book: Book(
            id: 'book-$id',
            title: title,
            authors: ['著者'],
            source: BookSource.manual,
            createdAt: '2026-01-01T00:00:00Z',
          ),
          status: status,
          medium: BookMedium.physical,
          createdAt: '2026-01-01T00:00:00Z',
        );

    Widget testHistoryScreenWithBooks(List<UserBook> books) {
      final notifier = BookDataNotifier();
      for (final book in books) {
        notifier.addUserBook(book);
      }
      final completedCount =
          books.where((b) => b.status == BookStatus.completed).length;
      final adventurerNotifier = AdventurerNotifier();
      adventurerNotifier.state = AdventurerStats(
        level: adventurerNotifier.state.level,
        xp: adventurerNotifier.state.xp,
        xpToNextLevel: adventurerNotifier.state.xpToNextLevel,
        title: adventurerNotifier.state.title,
        totalBooksRegistered: books.length,
        totalBooksCompleted: completedCount,
        totalReadingMinutes: adventurerNotifier.state.totalReadingMinutes,
        totalPagesRead: adventurerNotifier.state.totalPagesRead,
        currentStreak: adventurerNotifier.state.currentStreak,
        longestStreak: adventurerNotifier.state.longestStreak,
        readingDates: adventurerNotifier.state.readingDates,
      );
      return ProviderScope(
        overrides: [
          bookDataProvider.overrideWith((ref) => notifier),
          adventurerProvider.overrideWith((ref) => adventurerNotifier),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const HistoryScreen(),
        ),
      );
    }

    testWidgets('登録数カードタップでBookListScreenに遷移すること',
        (tester) async {
      final books = [
        testBook('1', '積読本A', BookStatus.tsundoku),
        testBook('2', '読書中B', BookStatus.reading),
        testBook('3', '読了本C', BookStatus.completed),
      ];
      await tester.pumpWidget(testHistoryScreenWithBooks(books));
      await tester.pumpAndSettle();

      // 登録数カードを探してタップ
      final statCard = find.text('3');
      expect(statCard, findsWidgets);
      await tester.tap(statCard.first);
      await tester.pumpAndSettle();

      // BookListScreen が表示されていることを確認
      expect(find.byKey(AppKeys.bookListScreen), findsOneWidget);
    });

    testWidgets('読了数カードタップで討伐済み一覧に遷移すること',
        (tester) async {
      final books = [
        testBook('1', '積読本A', BookStatus.tsundoku),
        testBook('2', '読了本B', BookStatus.completed),
      ];
      await tester.pumpWidget(testHistoryScreenWithBooks(books));
      await tester.pumpAndSettle();

      await tester.tap(find.text('読了数'));
      await tester.pumpAndSettle();

      expect(find.text('📋 討伐済み一覧'), findsOneWidget);
    });

    testWidgets('読了数タップでcompleted本のみ表示されること',
        (tester) async {
      final books = [
        testBook('1', '積読本A', BookStatus.tsundoku),
        testBook('2', '読了本B', BookStatus.completed),
        testBook('3', '読了本C', BookStatus.completed),
      ];
      await tester.pumpWidget(testHistoryScreenWithBooks(books));
      await tester.pumpAndSettle();

      await tester.tap(find.text('読了数'));
      await tester.pumpAndSettle();

      expect(find.text('読了本B'), findsOneWidget);
      expect(find.text('読了本C'), findsOneWidget);
      expect(find.text('積読本A'), findsNothing);
    });
  });
}
