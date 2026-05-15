import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/book_card.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

Widget testBookshelfScreen() {
  return ProviderScope(
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

void main() {
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

      expect(find.text('今日のクエスト'), findsOneWidget);
    });

    testWidgets('should show empty state when no books', (tester) async {
      await tester.pumpWidget(testBookshelfScreen());

      expect(find.text('書庫はまだ空です'), findsOneWidget);
      expect(find.text('探索に出る'), findsOneWidget);
    });

    testWidgets('should show bookshelf sections', (tester) async {
      await tester.pumpWidget(testBookshelfScreen());

      expect(find.text('待機中の冒険'), findsOneWidget);
      expect(find.text('討伐済'), findsOneWidget);
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
}
