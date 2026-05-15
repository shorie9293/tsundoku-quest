import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';

void main() {
  group('BookStatus', () {
    test('should have three statuses', () {
      expect(BookStatus.values.length, 3);
      expect(BookStatus.tsundoku.value, 'tsundoku');
      expect(BookStatus.reading.value, 'reading');
      expect(BookStatus.completed.value, 'completed');
    });

    test('fromString should parse correctly', () {
      expect(BookStatus.fromString('tsundoku'), BookStatus.tsundoku);
      expect(BookStatus.fromString('reading'), BookStatus.reading);
      expect(BookStatus.fromString('completed'), BookStatus.completed);
    });

    test('fromString should default to tsundoku for unknown value', () {
      expect(BookStatus.fromString('unknown'), BookStatus.tsundoku);
    });
  });

  group('BookMedium', () {
    test('should have three mediums', () {
      expect(BookMedium.values.length, 3);
      expect(BookMedium.physical.value, 'physical');
      expect(BookMedium.ebook.value, 'ebook');
      expect(BookMedium.audiobook.value, 'audiobook');
    });
  });

  group('UserBook.fromJson', () {
    test('should parse full JSON with embedded book', () {
      final json = {
        'id': 'ub-1',
        'userId': 'user-1',
        'bookId': 'book-1',
        'book': {
          'id': 'book-1',
          'title': 'テストの本',
          'authors': ['著者'],
          'source': 'rakuten',
          'createdAt': '2026-01-01T00:00:00Z',
        },
        'status': 'reading',
        'medium': 'physical',
        'currentPage': 42,
        'totalReadingMinutes': 120,
        'rating': 4,
        'startedAt': '2026-05-01T10:00:00Z',
        'completedAt': null,
        'notes': '面白い',
        'createdAt': '2026-05-01T09:00:00Z',
      };

      final userBook = UserBook.fromJson(json);

      expect(userBook.id, 'ub-1');
      expect(userBook.userId, 'user-1');
      expect(userBook.bookId, 'book-1');
      expect(userBook.book, isNotNull);
      expect(userBook.book!.title, 'テストの本');
      expect(userBook.status, BookStatus.reading);
      expect(userBook.medium, BookMedium.physical);
      expect(userBook.currentPage, 42);
      expect(userBook.totalReadingMinutes, 120);
      expect(userBook.rating, 4);
      expect(userBook.startedAt, '2026-05-01T10:00:00Z');
      expect(userBook.completedAt, isNull);
      expect(userBook.notes, '面白い');
    });

    test('should handle minimal JSON with defaults', () {
      final json = {
        'id': 'ub-min',
        'userId': 'user-1',
        'bookId': 'book-1',
        'status': 'tsundoku',
        'medium': 'ebook',
        'createdAt': '2026-01-01T00:00:00Z',
      };

      final userBook = UserBook.fromJson(json);

      expect(userBook.id, 'ub-min');
      expect(userBook.book, isNull);
      expect(userBook.currentPage, 0);
      expect(userBook.totalReadingMinutes, 0);
      expect(userBook.rating, isNull);
      expect(userBook.startedAt, isNull);
      expect(userBook.completedAt, isNull);
      expect(userBook.notes, isNull);
    });
  });

  group('UserBook.toJson', () {
    test('should serialize to JSON', () {
      final userBook = UserBook(
        id: 'ub-2',
        userId: 'user-2',
        bookId: 'book-2',
        status: BookStatus.completed,
        medium: BookMedium.audiobook,
        currentPage: 300,
        totalReadingMinutes: 600,
        rating: 5,
        startedAt: '2026-03-01T00:00:00Z',
        completedAt: '2026-04-15T00:00:00Z',
        notes: '名著',
        createdAt: '2026-03-01T00:00:00Z',
      );

      final json = userBook.toJson();

      expect(json['id'], 'ub-2');
      expect(json['status'], 'completed');
      expect(json['medium'], 'audiobook');
      expect(json['currentPage'], 300);
      expect(json['totalReadingMinutes'], 600);
      expect(json['rating'], 5);
      // bookは出力しない（ネスト防止）
      expect(json['book'], isNull);
    });
  });
}
