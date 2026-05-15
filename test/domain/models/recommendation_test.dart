import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/recommendation.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';

void main() {
  group('Recommendation model', () {
    test('fromParams creates with all fields', () {
      final rec = Recommendation.fromParams(
        id: 'rec-1',
        bookTitle: 'テスト本',
        author: '著者A',
        reason: '今日のランダムな一冊',
        imageUrl: 'https://example.com/cover.jpg',
        createdAt: '2026-05-11T00:00:00Z',
      );

      expect(rec.id, 'rec-1');
      expect(rec.bookTitle, 'テスト本');
      expect(rec.author, '著者A');
      expect(rec.reason, '今日のランダムな一冊');
      expect(rec.imageUrl, 'https://example.com/cover.jpg');
      expect(rec.createdAt, '2026-05-11T00:00:00Z');
    });

    test('fromUserBook derives bookTitle/author from book', () {
      final book = Book(
        id: 'b1',
        title: '本のタイトル',
        authors: ['著者X'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      final userBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'b1',
        book: book,
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        createdAt: '2026-01-01T00:00:00Z',
      );

      final rec = Recommendation.fromUserBook(
        userBook,
        reason: 'おすすめ理由',
      );

      expect(rec.bookTitle, '本のタイトル');
      expect(rec.author, '著者X');
      expect(rec.imageUrl, isNull);
      expect(rec.book, userBook);
    });

    test('fromUserBook explicit overrides take precedence', () {
      final book = Book(
        id: 'b1',
        title: '元のタイトル',
        authors: ['元の著者'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      final userBook = UserBook(
        id: 'ub-1',
        userId: 'user-1',
        bookId: 'b1',
        book: book,
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        createdAt: '2026-01-01T00:00:00Z',
      );

      final rec = Recommendation.fromUserBook(
        userBook,
        reason: '理由',
        bookTitle: '上書きタイトル',
        author: '上書き著者',
      );

      expect(rec.bookTitle, '上書きタイトル');
      expect(rec.author, '上書き著者');
    });

    test('fromParams with defaults gives 不明 strings', () {
      final rec = Recommendation.fromParams(
        reason: 'テスト理由',
      );

      expect(rec.bookTitle, '不明なタイトル');
      expect(rec.author, '不明な著者');
      expect(rec.id, '');
      expect(rec.createdAt, '');
    });

    test('fromUserBook with all explicit fields', () {
      final book = Book(
        id: 'b1',
        title: '工場テスト',
        authors: ['著者Z'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
        coverImageUrl: 'https://img.example.com/cover.jpg',
      );
      final userBook = UserBook(
        id: 'ub-2',
        userId: 'user-1',
        bookId: 'b1',
        book: book,
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        createdAt: '2026-05-10T00:00:00Z',
      );

      final rec = Recommendation.fromUserBook(
        userBook,
        reason: '工場製のおすすめ',
      );

      expect(rec.bookTitle, '工場テスト');
      expect(rec.author, '著者Z');
      expect(rec.reason, '工場製のおすすめ');
      expect(rec.imageUrl, 'https://img.example.com/cover.jpg');
      expect(rec.id, 'ub-2');
    });

    test('fromUserBook handles book with no authors', () {
      final book = Book(
        id: 'b1',
        title: '無著者の本',
        authors: [],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      );
      final userBook = UserBook(
        id: 'ub-3',
        userId: 'user-1',
        bookId: 'b1',
        book: book,
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        createdAt: '2026-01-01T00:00:00Z',
      );

      final rec = Recommendation.fromUserBook(
        userBook,
        reason: '理由',
      );

      expect(rec.bookTitle, '無著者の本');
      expect(rec.author, '不明な著者');
    });
  });
}
