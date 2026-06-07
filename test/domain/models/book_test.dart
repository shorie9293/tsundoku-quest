import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';

void main() {
  group('BookSource', () {
    test('各ソースのvalueが正しい', () {
      expect(BookSource.openbd.value, 'openbd');
      expect(BookSource.googleBooks.value, 'google_books');
      expect(BookSource.rakuten.value, 'rakuten');
      expect(BookSource.manual.value, 'manual');
    });

    test('fromString で正しい列挙値を返す', () {
      expect(BookSource.fromString('openbd'), BookSource.openbd);
      expect(BookSource.fromString('google_books'), BookSource.googleBooks);
      expect(BookSource.fromString('rakuten'), BookSource.rakuten);
      expect(BookSource.fromString('manual'), BookSource.manual);
    });

    test('fromString 不明な値は manual にフォールバック', () {
      expect(BookSource.fromString('unknown'), BookSource.manual);
      expect(BookSource.fromString(''), BookSource.manual);
    });
  });

  group('Book', () {
    const sampleBook = Book(
      id: 'book-1',
      isbn13: '978-4-123456-78-9',
      isbn10: '4-123456-78-9',
      title: 'Dartプログラミング入門',
      authors: ['山田太郎', '鈴木花子'],
      publisher: '技術書院',
      publishedDate: '2025-01-15',
      description: 'Dart言語の基礎から応用まで',
      pageCount: 350,
      coverImageUrl: 'https://example.com/cover.jpg',
      source: BookSource.openbd,
      createdAt: '2025-01-20T10:00:00Z',
    );

    test('全フィールドが正しく設定される', () {
      expect(sampleBook.id, 'book-1');
      expect(sampleBook.isbn13, '978-4-123456-78-9');
      expect(sampleBook.isbn10, '4-123456-78-9');
      expect(sampleBook.title, 'Dartプログラミング入門');
      expect(sampleBook.authors, ['山田太郎', '鈴木花子']);
      expect(sampleBook.publisher, '技術書院');
      expect(sampleBook.publishedDate, '2025-01-15');
      expect(sampleBook.description, 'Dart言語の基礎から応用まで');
      expect(sampleBook.pageCount, 350);
      expect(sampleBook.coverImageUrl, 'https://example.com/cover.jpg');
      expect(sampleBook.source, BookSource.openbd);
      expect(sampleBook.createdAt, '2025-01-20T10:00:00Z');
    });

    test('authors デフォルトは空リスト', () {
      const book = Book(
        id: 'b',
        title: 'T',
        source: BookSource.manual,
        createdAt: '2025-01-01',
      );
      expect(book.authors, isEmpty);
    });

    test('nullable フィールドは null 可', () {
      const book = Book(
        id: 'b',
        title: 'T',
        source: BookSource.manual,
        createdAt: '2025-01-01',
      );
      expect(book.isbn13, isNull);
      expect(book.isbn10, isNull);
      expect(book.publisher, isNull);
      expect(book.publishedDate, isNull);
      expect(book.description, isNull);
      expect(book.pageCount, isNull);
      expect(book.coverImageUrl, isNull);
    });

    group('fromJson', () {
      test('全フィールドを正しく復元', () {
        final json = {
          'id': 'book-1',
          'isbn13': '978-4-123456-78-9',
          'isbn10': '4-123456-78-9',
          'title': 'Dart入門',
          'authors': ['山田太郎'],
          'publisher': '技術書院',
          'publishedDate': '2025-01-15',
          'description': 'Dartの入門書',
          'pageCount': 300,
          'coverImageUrl': 'https://example.com/cover.jpg',
          'source': 'openbd',
          'createdAt': '2025-01-20',
        };

        final book = Book.fromJson(json);

        expect(book.id, 'book-1');
        expect(book.title, 'Dart入門');
        expect(book.authors, ['山田太郎']);
        expect(book.pageCount, 300);
        expect(book.source, BookSource.openbd);
      });

      test('authors が null でも空リストに', () {
        final json = {
          'id': 'b',
          'title': 'T',
          'source': 'openbd',
          'createdAt': '2025-01-20',
          'authors': null,
        };

        final book = Book.fromJson(json);
        expect(book.authors, isEmpty);
      });

      test('ページ指定なし', () {
        final json = {
          'id': 'b',
          'title': 'T',
          'source': 'manual',
          'createdAt': '2025-01-20',
        };

        final book = Book.fromJson(json);
        expect(book.pageCount, isNull);
        expect(book.isbn13, isNull);
      });
    });

    group('toJson', () {
      test('全フィールドを正しくJSON化', () {
        final json = sampleBook.toJson();

        expect(json['id'], 'book-1');
        expect(json['title'], 'Dartプログラミング入門');
        expect(json['authors'], ['山田太郎', '鈴木花子']);
        expect(json['source'], 'openbd'); // value が使われる
        expect(json['pageCount'], 350);
      });

      test('ラウンドトリップ（fromJson → toJson → fromJson）', () {
        const original = Book(
          id: 'roundtrip-1',
          isbn13: '978-4-000000-00-0',
          title: '往復テスト',
          authors: ['テスト著者'],
          publisher: 'テスト出版',
          publishedDate: '2025-06-01',
          description: '往復確認用',
          pageCount: 200,
          source: BookSource.manual,
          createdAt: '2025-06-01T00:00:00Z',
        );

        final json = original.toJson();
        final restored = Book.fromJson(json);

        expect(restored, original);
      });
    });

    group('== と hashCode', () {
      test('同一フィールドなら等価', () {
        const a = Book(
          id: 'same',
          title: 'Same',
          source: BookSource.manual,
          createdAt: '2025-01-01',
        );
        const b = Book(
          id: 'same',
          title: 'Same',
          source: BookSource.manual,
          createdAt: '2025-01-01',
        );
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('id が異なれば非等価', () {
        const a = Book(
          id: 'a',
          title: 'Same',
          source: BookSource.manual,
          createdAt: '2025-01-01',
        );
        const b = Book(
          id: 'b',
          title: 'Same',
          source: BookSource.manual,
          createdAt: '2025-01-01',
        );
        expect(a, isNot(b));
      });

      test('authors が異なれば非等価', () {
        const a = Book(
          id: 'same',
          title: 'Same',
          authors: ['A'],
          source: BookSource.manual,
          createdAt: '2025-01-01',
        );
        const b = Book(
          id: 'same',
          title: 'Same',
          authors: ['B'],
          source: BookSource.manual,
          createdAt: '2025-01-01',
        );
        expect(a, isNot(b));
      });
    });
  });
}
