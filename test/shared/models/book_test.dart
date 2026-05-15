import 'package:flutter_test/flutter_test.dart';

// 注: このテストはまだ実装されていないBookモデルをテストする
// TDDのREDフェーズ: まず失敗させる
import 'package:tsundoku_quest/domain/models/book.dart';

void main() {
  group('BookSource', () {
    test('should have four sources', () {
      expect(BookSource.values.length, 4);
      expect(
          BookSource.values,
          containsAll([
            BookSource.openbd,
            BookSource.googleBooks,
            BookSource.rakuten,
            BookSource.manual,
          ]));
    });
  });

  group('Book.fromJson', () {
    test('should parse full JSON with all fields', () {
      final json = {
        'id': 'book-1',
        'isbn13': '9781234567890',
        'isbn10': '123456789X',
        'title': 'Flutter実践入門',
        'authors': ['山田太郎', '鈴木花子'],
        'publisher': '技術評論社',
        'publishedDate': '2025-03',
        'description': 'Flutter開発のすべてがわかる一冊',
        'pageCount': 480,
        'coverImageUrl': 'https://example.com/cover.jpg',
        'source': 'rakuten',
        'createdAt': '2026-05-04T10:00:00Z',
      };

      final book = Book.fromJson(json);

      expect(book.id, 'book-1');
      expect(book.isbn13, '9781234567890');
      expect(book.isbn10, '123456789X');
      expect(book.title, 'Flutter実践入門');
      expect(book.authors, ['山田太郎', '鈴木花子']);
      expect(book.publisher, '技術評論社');
      expect(book.publishedDate, '2025-03');
      expect(book.description, 'Flutter開発のすべてがわかる一冊');
      expect(book.pageCount, 480);
      expect(book.coverImageUrl, 'https://example.com/cover.jpg');
      expect(book.source, BookSource.rakuten);
      expect(book.createdAt, '2026-05-04T10:00:00Z');
    });

    test('should handle minimal JSON with null fields', () {
      final json = {
        'id': 'book-min',
        'title': '最小の本',
        'authors': <String>[],
        'source': 'manual',
        'createdAt': '2026-01-01T00:00:00Z',
      };

      final book = Book.fromJson(json);

      expect(book.id, 'book-min');
      expect(book.title, '最小の本');
      expect(book.isbn13, isNull);
      expect(book.isbn10, isNull);
      expect(book.authors, isEmpty);
      expect(book.publisher, isNull);
      expect(book.publishedDate, isNull);
      expect(book.description, isNull);
      expect(book.pageCount, isNull);
      expect(book.coverImageUrl, isNull);
      expect(book.source, BookSource.manual);
    });

    test('should default authors to empty list when missing', () {
      final json = {
        'id': 'book-no-authors',
        'title': '著者なし',
        'source': 'openbd',
        'createdAt': '2026-01-01T00:00:00Z',
      };

      final book = Book.fromJson(json);

      expect(book.authors, isEmpty);
    });
  });

  group('Book.toJson', () {
    test('should serialize all fields to JSON', () {
      final book = Book(
        id: 'book-2',
        isbn13: '9789876543210',
        isbn10: null,
        title: 'テスト駆動開発',
        authors: ['Kent Beck'],
        publisher: 'オーム社',
        publishedDate: null,
        description: null,
        pageCount: 256,
        coverImageUrl: null,
        source: BookSource.googleBooks,
        createdAt: '2026-05-04T12:00:00Z',
      );

      final json = book.toJson();

      expect(json['id'], 'book-2');
      expect(json['isbn13'], '9789876543210');
      expect(json['isbn10'], isNull);
      expect(json['title'], 'テスト駆動開発');
      expect(json['authors'], ['Kent Beck']);
      expect(json['source'], 'google_books');
      expect(json['pageCount'], 256);
    });

    test('should round-trip through fromJson/toJson', () {
      final originalJson = {
        'id': 'book-3',
        'title': '往復テスト',
        'authors': ['テスト花子'],
        'source': 'rakuten',
        'createdAt': '2026-05-04T12:00:00Z',
        'isbn13': '9784000000000',
        'isbn10': '4000000000',
        'publisher': 'テスト出版',
        'pageCount': 100,
      };

      final book = Book.fromJson(originalJson);
      final roundTripped = book.toJson();

      expect(roundTripped['id'], originalJson['id']);
      expect(roundTripped['title'], originalJson['title']);
      expect(roundTripped['source'], originalJson['source']);
      expect(roundTripped['isbn13'], originalJson['isbn13']);
    });
  });

  group('Book equality', () {
    test('should be equal when all fields match', () {
      final book1 = Book(
        id: 'same',
        title: '同じ本',
        authors: ['著者A'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      final book2 = Book(
        id: 'same',
        title: '同じ本',
        authors: ['著者A'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );

      expect(book1, equals(book2));
    });

    test('should not be equal when id differs', () {
      final book1 = Book(
        id: 'book-a',
        title: '本',
        authors: ['著者'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      final book2 = Book(
        id: 'book-b',
        title: '本',
        authors: ['著者'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );

      expect(book1, isNot(equals(book2)));
    });
  });
}
