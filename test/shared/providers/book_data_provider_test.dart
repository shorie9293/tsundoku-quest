import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

Book _testBook(String id) => Book(
      id: id,
      title: 'テスト本 $id',
      authors: ['著者'],
      source: BookSource.manual,
      createdAt: '2026-01-01T00:00:00Z',
    );

UserBook _testUserBook(String id, BookStatus status) => UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      status: status,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  group('BookDataNotifier', () {
    test('initial state is empty', () {
      final notifier = BookDataNotifier();
      expect(notifier.state.books, isEmpty);
      expect(notifier.state.userBooks, isEmpty);
      expect(notifier.state.trophies, isEmpty);
    });

    group('addBook', () {
      test('should add a book to state', () {
        final notifier = BookDataNotifier();
        final book = _testBook('book-1');

        notifier.addBook(book);

        expect(notifier.state.books.length, 1);
        expect(notifier.state.books[0].id, 'book-1');
      });

      test('should replace book with same id', () {
        final notifier = BookDataNotifier();
        final book1 = _testBook('book-1');
        final book2 = Book(
          id: 'book-1',
          title: '更新後の本',
          authors: ['新しい著者'],
          source: BookSource.rakuten,
          createdAt: '2026-02-01T00:00:00Z',
        );

        notifier.addBook(book1);
        notifier.addBook(book2);

        expect(notifier.state.books.length, 1);
        expect(notifier.state.books[0].title, '更新後の本');
        expect(notifier.state.books[0].source, BookSource.rakuten);
      });
    });

    group('getBook', () {
      test('should return book by id', () {
        final notifier = BookDataNotifier();
        final book = _testBook('book-1');
        notifier.addBook(book);

        final result = notifier.getBook('book-1');
        expect(result, isNotNull);
        expect(result!.id, 'book-1');
      });

      test('should return null for unknown id', () {
        final notifier = BookDataNotifier();
        expect(notifier.getBook('nonexistent'), isNull);
      });
    });

    group('addUserBook / updateUserBook / removeUserBook', () {
      test('should add a user book', () {
        final notifier = BookDataNotifier();
        final userBook = _testUserBook('ub-1', BookStatus.tsundoku);

        notifier.addUserBook(userBook);

        expect(notifier.state.userBooks.length, 1);
        expect(notifier.state.userBooks[0].status, BookStatus.tsundoku);
      });

      test('should update existing user book', () {
        final notifier = BookDataNotifier();
        notifier.addUserBook(_testUserBook('ub-1', BookStatus.tsundoku));

        notifier.updateUserBook(
          id: 'ub-1',
          status: BookStatus.reading,
          currentPage: 42,
        );

        final updated = notifier.state.userBooks[0];
        expect(updated.status, BookStatus.reading);
        expect(updated.currentPage, 42);
      });

      test('should remove user book', () {
        final notifier = BookDataNotifier();
        notifier.addUserBook(_testUserBook('ub-1', BookStatus.tsundoku));
        notifier.addUserBook(_testUserBook('ub-2', BookStatus.reading));

        notifier.removeUserBook('ub-1');

        expect(notifier.state.userBooks.length, 1);
        expect(notifier.state.userBooks[0].id, 'ub-2');
      });
    });

    group('addTrophy / getTrophy', () {
      test('should add a trophy', () {
        final notifier = BookDataNotifier();
        final trophy = WarTrophy(
          id: 'wt-1',
          userBookId: 'ub-1',
          userId: 'user-1',
          learnings: ['学び1', '学び2', '学び3'],
          action: 'アクション',
          createdAt: '2026-05-04T10:00:00Z',
        );

        notifier.addTrophy(trophy);

        expect(notifier.state.trophies.length, 1);
        expect(notifier.getTrophy('wt-1'), isNotNull);
      });

      test('getTrophy should return null for unknown id', () {
        final notifier = BookDataNotifier();
        expect(notifier.getTrophy('unknown'), isNull);
      });
    });
  });
}
