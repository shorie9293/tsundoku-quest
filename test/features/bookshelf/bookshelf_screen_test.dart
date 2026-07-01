import 'package:hive/hive.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/book_card.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';
import 'package:tsundoku_quest/features/shared/providers/war_trophy_provider.dart';

Widget testBookshelfScreen() {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const BookshelfScreen(),
    ),
  );
}

Widget testBookshelfScreenWithContainer({
  required ProviderContainer container,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: const BookshelfScreen(),
    ),
  );
}

Book _testBook(String id) => Book(
      id: id,
      title: 'テスト本 $id',
      authors: ['著者'],
      source: BookSource.manual,
      createdAt: '2026-01-01T00:00:00Z',
    );

UserBook _testUserBook(String id, BookStatus status, {Book? book}) =>
    UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      book: book,
      status: status,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );


void _initTestHive() {
  final tempDir = Directory.systemTemp.createTempSync('hive_test_');
  Hive.init(tempDir.path);
}

void main() {
  setUpAll(() {
    _initTestHive();
  });
  tearDownAll(() async {
    await Hive.close();
  });

  // DailyQuest が内部で SharedPreferences を使うため mock 初期化
  SharedPreferences.setMockInitialValues({});

  group('BookshelfScreen', () {
    testWidgets('should display app bar with title', (tester) async {
      await tester.pumpWidget(testBookshelfScreen());

      expect(find.text('📚 書庫'), findsOneWidget);
    });

    testWidgets('should show adventurer header', (tester) async {
      await tester.pumpWidget(testBookshelfScreen());

      expect(find.byKey(AppKeys.adventurerHeader), findsOneWidget);
    });

    testWidgets('should show daily quest', (tester) async {
      await tester.pumpWidget(testBookshelfScreen());
      // DailyMissionNotifier が非同期で SharedPreferences から読み込むのを待つ
      await tester.pumpAndSettle();

      expect(find.text('今日のクエスト'), findsOneWidget);
    });

    testWidgets('should show empty state when no books', (tester) async {
      await tester.pumpWidget(testBookshelfScreen());

      expect(find.text('書庫はまだ空です'), findsOneWidget);
      expect(find.text('探索に出る'), findsOneWidget);
    });

    testWidgets('should show bookshelf sections when books exist',
        (tester) async {
      final container = ProviderContainer();
      final book = _testBook('b1');
      container.read(bookDataProvider.notifier).addUserBook(
            _testUserBook('ub-1', BookStatus.completed, book: book),
          );
      container.read(bookDataProvider.notifier).addUserBook(
            _testUserBook('ub-2', BookStatus.tsundoku, book: book),
          );

      await tester.pumpWidget(
        testBookshelfScreenWithContainer(container: container),
      );
      await tester.pumpAndSettle();

      // Scroll to reveal sections below the fold
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(find.text('待機中の冒険'), findsOneWidget);
      expect(find.text('討伐済'), findsOneWidget);
      container.dispose();
    });
  });

  group('BookCard delete functionality', () {
    testWidgets('should show edit and delete options in popup menu',
        (tester) async {
      final book = _testBook('b1');
      final userBook = _testUserBook('ub-1', BookStatus.tsundoku, book: book);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BookCard(
            book: userBook,
            onTap: () {},
            onEdit: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap the popup menu button (more_vert icon)
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Should show both options
      expect(find.text('編集'), findsOneWidget);
      expect(find.text('削除'), findsOneWidget);
    });

    testWidgets('should call onDelete when tapping delete from popup menu',
        (tester) async {
      bool deleted = false;
      final book = _testBook('b1');
      final userBook = _testUserBook('ub-1', BookStatus.tsundoku, book: book);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BookCard(
            book: userBook,
            onTap: () {},
            onEdit: () {},
            onDelete: () => deleted = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap "削除"
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('should show Dismissible with delete background',
        (tester) async {
      final book = _testBook('b1');
      final userBook = _testUserBook('ub-1', BookStatus.tsundoku, book: book);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BookCard(
            book: userBook,
            onTap: () {},
            onEdit: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Dismissible should be present
      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('should show confirmation dialog when swiping Dismissible',
        (tester) async {
      final book = _testBook('b1');
      final userBook = _testUserBook('ub-1', BookStatus.tsundoku, book: book);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BookCard(
            book: userBook,
            onTap: () {},
            onEdit: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Swipe left on the Dismissible
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.byKey(AppKeys.confirmDialog), findsOneWidget);
      expect(find.text('本を削除しますか？'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
      expect(find.text('削除する'), findsOneWidget);
    });
  });

  group('BookDataProvider removeUserBook', () {
    test('should remove book from notifier state', () {
      final notifier = BookDataNotifier();
      final book = _testBook('b1');
      notifier.addBook(book);
      notifier.addUserBook(_testUserBook('ub-1', BookStatus.tsundoku, book: book));

      expect(notifier.state.userBooks.length, 1);

      notifier.removeUserBook('ub-1');

      expect(notifier.state.userBooks.length, 0);
    });
  });

  group('Completed section behavior', () {
    testWidgets('should hide section header when no completed books',
        (tester) async {
      // Only add non-completed books; section header should not appear
      final container = ProviderContainer();
      container.read(bookDataProvider.notifier).addUserBook(
            _testUserBook('ub-1', BookStatus.reading),
          );

      await tester.pumpWidget(
        testBookshelfScreenWithContainer(container: container),
      );
      await tester.pumpAndSettle();

      // Scroll to reveal sections below the fold
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(find.text('討伐済'), findsNothing);
      container.dispose();
    });

    testWidgets('should show section header when completed books exist',
        (tester) async {
      final container = ProviderContainer();
      final book = _testBook('b1');
      container.read(bookDataProvider.notifier).addUserBook(
            _testUserBook('ub-1', BookStatus.completed, book: book),
          );

      await tester.pumpWidget(
        testBookshelfScreenWithContainer(container: container),
      );
      await tester.pumpAndSettle();

      // Scroll to reveal sections below the fold
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(find.text('討伐済'), findsOneWidget);
      container.dispose();
    });

    testWidgets('should be expanded by default showing book cards',
        (tester) async {
      final container = ProviderContainer();
      final book = _testBook('b1');
      container.read(bookDataProvider.notifier).addUserBook(
            _testUserBook('ub-1', BookStatus.completed, book: book),
          );

      await tester.pumpWidget(
        testBookshelfScreenWithContainer(container: container),
      );
      await tester.pumpAndSettle();

      // Scroll to reveal sections below the fold
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      // Completed book card should be visible without any toggle
      expect(find.text('テスト本 b1'), findsOneWidget);
      container.dispose();
    });
  });

  group('BookCard completed status display', () {
    testWidgets('should show stars for completed book with rating',
        (tester) async {
      final book = _testBook('b1');
      final userBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'book-b1',
        book: book,
        status: BookStatus.completed,
        medium: BookMedium.physical,
        rating: 4,
        totalReadingMinutes: 120,
        completedAt: '2026-06-01T10:00:00Z',
        createdAt: '2026-01-01T00:00:00Z',
      );

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: BookCard(
            book: userBook,
            onTap: () {},
            onEdit: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsAtLeastNWidgets(1));
    });

    testWidgets('should show completion date for completed book',
        (tester) async {
      final book = _testBook('b1');
      final userBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'book-b1',
        book: book,
        status: BookStatus.completed,
        medium: BookMedium.physical,
        rating: 4,
        totalReadingMinutes: 120,
        completedAt: '2026-06-01T10:00:00Z',
        createdAt: '2026-01-01T00:00:00Z',
      );

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: BookCard(
            book: userBook,
            onTap: () {},
            onEdit: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('2026/06/01'), findsOneWidget);
    });

    testWidgets('should not show stars for non-completed book',
        (tester) async {
      final book = _testBook('b1');
      final userBook = _testUserBook('ub-1', BookStatus.reading, book: book);

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: BookCard(
            book: userBook,
            onTap: () {},
            onEdit: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsNothing);
    });
  });

  group('Completed book detail modal', () {
    testWidgets('tapping completed book should show detail bottom sheet',
        (tester) async {
      final container = ProviderContainer();
      final book = _testBook('b1');
      container.read(bookDataProvider.notifier).addUserBook(UserBook(
            id: 'ub-1',
            userId: 'user-1',
            bookId: 'book-b1',
            book: book,
            status: BookStatus.completed,
            medium: BookMedium.physical,
            rating: 4,
            totalReadingMinutes: 120,
            completedAt: '2026-06-01T10:00:00Z',
            createdAt: '2026-01-01T00:00:00Z',
          ));
      container.read(warTrophyProvider.notifier).addTrophy(const WarTrophy(
            id: 'trophy-ub-1',
            userBookId: 'ub-1',
            userId: 'user-1',
            learnings: ['集中力の大切さ', '継続は力なり', '知識の連鎖'],
            action: '毎日30分読書する',
            favoriteQuote: '千里の道も一歩から',
            createdAt: '2026-06-01T10:00:00Z',
          ));

      await tester.pumpWidget(
        testBookshelfScreenWithContainer(container: container),
      );
      await tester.pumpAndSettle();

      // Scroll to reveal completed section
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      // Tap the completed book card
      await tester.tap(find.text('テスト本 b1'));
      await tester.pumpAndSettle();

      // Bottom sheet should appear with war trophy info
      expect(find.text('⚔️ 戦利品'), findsOneWidget);
      container.dispose();
    });

    testWidgets('modal should show learnings, action, and favorite quote',
        (tester) async {
      final container = ProviderContainer();
      final book = _testBook('b1');
      container.read(bookDataProvider.notifier).addUserBook(UserBook(
            id: 'ub-1',
            userId: 'user-1',
            bookId: 'book-b1',
            book: book,
            status: BookStatus.completed,
            medium: BookMedium.physical,
            rating: 4,
            totalReadingMinutes: 120,
            completedAt: '2026-06-01T10:00:00Z',
            createdAt: '2026-01-01T00:00:00Z',
          ));
      container.read(warTrophyProvider.notifier).addTrophy(const WarTrophy(
            id: 'trophy-ub-1',
            userBookId: 'ub-1',
            userId: 'user-1',
            learnings: ['集中力の大切さ', '継続は力なり', '知識の連鎖'],
            action: '毎日30分読書する',
            favoriteQuote: '千里の道も一歩から',
            createdAt: '2026-06-01T10:00:00Z',
          ));

      await tester.pumpWidget(
        testBookshelfScreenWithContainer(container: container),
      );
      await tester.pumpAndSettle();

      // Scroll to reveal completed section
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      await tester.tap(find.text('テスト本 b1'));
      await tester.pumpAndSettle();

      expect(find.text('集中力の大切さ'), findsOneWidget);
      expect(find.text('継続は力なり'), findsOneWidget);
      expect(find.text('知識の連鎖'), findsOneWidget);
      expect(find.text('毎日30分読書する'), findsOneWidget);
      expect(find.text('千里の道も一歩から'), findsOneWidget);
      container.dispose();
    });

    testWidgets('modal should show rating and reading time',
        (tester) async {
      final container = ProviderContainer();
      final book = _testBook('b1');
      container.read(bookDataProvider.notifier).addUserBook(UserBook(
            id: 'ub-1',
            userId: 'user-1',
            bookId: 'book-b1',
            book: book,
            status: BookStatus.completed,
            medium: BookMedium.physical,
            rating: 4,
            totalReadingMinutes: 120,
            completedAt: '2026-06-01T10:00:00Z',
            createdAt: '2026-01-01T00:00:00Z',
          ));

      await tester.pumpWidget(
        testBookshelfScreenWithContainer(container: container),
      );
      await tester.pumpAndSettle();

      // Scroll to reveal completed section
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      await tester.tap(find.text('テスト本 b1'));
      await tester.pumpAndSettle();

      // Should show reading time (120分)
      expect(find.textContaining('120'), findsWidgets);
      // Should show completion date (appears in both card and modal)
      expect(find.textContaining('2026/06/01'), findsAtLeastNWidgets(1));
      container.dispose();
    });
  });
}
