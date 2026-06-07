import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/book_card.dart';

Widget createTestWidget({
  required UserBook book,
  required VoidCallback onTap,
  required VoidCallback onEdit,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BookCard(
        book: book,
        onTap: onTap,
        onEdit: onEdit,
      ),
    ),
  );
}

void main() {
  group('BookCard', () {
    testWidgets('should display book title and author', (tester) async {
      const testBook = Book(
        id: 'book-1',
        title: 'テストの書',
        authors: ['テスト太郎'],
        source: BookSource.manual,
        createdAt: '2024-01-01',
        pageCount: 300,
      );

      const testUserBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'book-1',
        book: testBook,
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        createdAt: '2024-01-01',
      );

      await tester.pumpWidget(createTestWidget(
        book: testUserBook,
        onTap: () {},
        onEdit: () {},
      ));

      expect(find.text('テストの書'), findsOneWidget);
      expect(find.text('テスト太郎'), findsOneWidget);
    });

    testWidgets("should display correct status label for tsundoku ('待機中')",
        (tester) async {
      const testBook = Book(
        id: 'book-1',
        title: 'テストの書',
        authors: ['テスト太郎'],
        source: BookSource.manual,
        createdAt: '2024-01-01',
      );

      const testUserBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'book-1',
        book: testBook,
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        createdAt: '2024-01-01',
      );

      await tester.pumpWidget(createTestWidget(
        book: testUserBook,
        onTap: () {},
        onEdit: () {},
      ));

      expect(find.text('待機中'), findsOneWidget);
    });

    testWidgets("should display correct status label for reading ('討伐中')",
        (tester) async {
      const testBook = Book(
        id: 'book-1',
        title: 'テストの書',
        authors: ['テスト太郎'],
        source: BookSource.manual,
        createdAt: '2024-01-01',
      );

      const testUserBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'book-1',
        book: testBook,
        status: BookStatus.reading,
        medium: BookMedium.physical,
        totalReadingMinutes: 30,
        currentPage: 50,
        createdAt: '2024-01-01',
      );

      await tester.pumpWidget(createTestWidget(
        book: testUserBook,
        onTap: () {},
        onEdit: () {},
      ));

      expect(find.text('討伐中'), findsOneWidget);
    });

    testWidgets(
        "should display correct status label for completed ('討伐完了')",
        (tester) async {
      const testBook = Book(
        id: 'book-1',
        title: 'テストの書',
        authors: ['テスト太郎'],
        source: BookSource.manual,
        createdAt: '2024-01-01',
      );

      const testUserBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'book-1',
        book: testBook,
        status: BookStatus.completed,
        medium: BookMedium.physical,
        createdAt: '2024-01-01',
      );

      await tester.pumpWidget(createTestWidget(
        book: testUserBook,
        onTap: () {},
        onEdit: () {},
      ));

      expect(find.text('討伐完了'), findsOneWidget);
    });

    testWidgets(
        'should display reading time for reading status',
        (tester) async {
      const testBook = Book(
        id: 'book-1',
        title: 'テストの書',
        authors: ['テスト太郎'],
        source: BookSource.manual,
        createdAt: '2024-01-01',
        pageCount: 300,
      );

      const testUserBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'book-1',
        book: testBook,
        status: BookStatus.reading,
        medium: BookMedium.physical,
        totalReadingMinutes: 45,
        currentPage: 100,
        createdAt: '2024-01-01',
      );

      await tester.pumpWidget(createTestWidget(
        book: testUserBook,
        onTap: () {},
        onEdit: () {},
      ));

      expect(find.text('45分 経過'), findsOneWidget);
    });

    testWidgets('should call onTap when card is tapped', (tester) async {
      const testBook = Book(
        id: 'book-1',
        title: 'テストの書',
        authors: ['テスト太郎'],
        source: BookSource.manual,
        createdAt: '2024-01-01',
      );

      const testUserBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'book-1',
        book: testBook,
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        createdAt: '2024-01-01',
      );

      bool tapped = false;
      await tester.pumpWidget(createTestWidget(
        book: testUserBook,
        onTap: () {
          tapped = true;
        },
        onEdit: () {},
      ));

      await tester.tap(find.text('テストの書'));
      expect(tapped, isTrue);
    });

    testWidgets("should show '不明な本' when book.book is null",
        (tester) async {
      const testUserBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'book-1',
        book: null,
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        createdAt: '2024-01-01',
      );

      await tester.pumpWidget(createTestWidget(
        book: testUserBook,
        onTap: () {},
        onEdit: () {},
      ));

      expect(find.text('不明な本'), findsOneWidget);
    });
  });
}
