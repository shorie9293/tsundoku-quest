import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/shared/repositories/book_search_service.dart';
import 'package:tsundoku_quest/shared/repositories/rakuten_api.dart';
import 'package:tsundoku_quest/shared/repositories/openbd_api.dart';
import 'package:tsundoku_quest/shared/repositories/google_books_api.dart';
import 'package:tsundoku_quest/domain/models/book.dart';

/// Fake RakutenApi for testing BookSearchService.
class FakeRakutenApi implements RakutenApi {
  List<Book> Function(String query)? _onSearch;
  Book? Function(String isbn)? _onLookupByIsbn;

  set onSearch(List<Book> Function(String query)? f) => _onSearch = f;
  set onLookupByIsbn(Book? Function(String isbn)? f) => _onLookupByIsbn = f;

  @override
  Future<List<Book>> search(String query) async {
    return _onSearch?.call(query) ?? [];
  }

  @override
  Future<Book?> lookupByIsbn(String isbn) async {
    return _onLookupByIsbn?.call(isbn);
  }
}

/// Fake OpenBDApi for testing BookSearchService.
class FakeOpenBDApi implements OpenBDApi {
  Book? Function(String isbn)? _onLookupByIsbn;

  set onLookupByIsbn(Book? Function(String isbn)? f) => _onLookupByIsbn = f;

  @override
  Future<Book?> lookupByIsbn(String isbn) async {
    return _onLookupByIsbn?.call(isbn);
  }
}

/// Fake GoogleBooksApi for testing BookSearchService.
class FakeGoogleBooksApi implements GoogleBooksApi {
  List<Book> Function(String query)? _onSearch;
  Book? Function(String isbn)? _onLookupByIsbn;

  set onSearch(List<Book> Function(String query)? f) => _onSearch = f;
  set onLookupByIsbn(Book? Function(String isbn)? f) => _onLookupByIsbn = f;

  @override
  Future<List<Book>> search(String query) async {
    return _onSearch?.call(query) ?? [];
  }

  @override
  Future<Book?> lookupByIsbn(String isbn) async {
    return _onLookupByIsbn?.call(isbn);
  }
}

/// Helper to create a Book quickly in tests.
Book _book({
  String id = 'test-id',
  String title = 'テスト本',
  BookSource source = BookSource.rakuten,
  String? isbn13,
}) {
  return Book(
    id: id,
    title: title,
    authors: ['テスト著者'],
    source: source,
    createdAt: '2026-01-01T00:00:00Z',
    isbn13: isbn13,
  );
}

void main() {
  late FakeRakutenApi fakeRakuten;
  late FakeOpenBDApi fakeOpenbd;
  late FakeGoogleBooksApi fakeGoogle;
  late BookSearchService service;

  setUp(() {
    fakeRakuten = FakeRakutenApi();
    fakeOpenbd = FakeOpenBDApi();
    fakeGoogle = FakeGoogleBooksApi();
    service = BookSearchService(
      rakuten: fakeRakuten,
      openbd: fakeOpenbd,
      googleBooks: fakeGoogle,
    );
  });

  // ━━━━━ search ━━━━━

  group('BookSearchService.search', () {
    test('should return Rakuten results when available', () async {
      final rakutenBook = _book(id: 'r1', title: '楽天の本');
      fakeRakuten.onSearch = (_) => [rakutenBook];

      final results = await service.search('テスト');

      expect(results.length, 1);
      expect(results.first.title, '楽天の本');
    });

    test('should NOT call OpenBD or Google when Rakuten returns results',
        () async {
      fakeRakuten.onSearch = (_) => [_book()];
      fakeOpenbd.onLookupByIsbn = (_) => _book(title: 'OpenBDの本');
      fakeGoogle.onSearch = (_) => [_book(title: 'Googleの本')];

      final results = await service.search('何でも');

      // Should only use Rakuten results
      expect(
          results.first.title, startsWith('テスト本')); // the default from _book()
    });

    test(
        'should fall back to OpenBD when Rakuten returns empty AND query is ISBN (13 digits)',
        () async {
      fakeRakuten.onSearch = (_) => [];
      fakeOpenbd.onLookupByIsbn =
          (isbn) => _book(id: 'obd', title: 'OpenBDから', isbn13: isbn);
      fakeGoogle.onSearch = (_) => [_book(title: 'Googleから')];

      final results = await service.search('9784000000000');

      expect(results.length, 1);
      expect(results.first.title, 'OpenBDから');
    });

    test('should fall back to OpenBD when query is ISBN (10 digits)', () async {
      fakeRakuten.onSearch = (_) => [];
      fakeOpenbd.onLookupByIsbn =
          (isbn) => _book(id: 'obd10', title: '10桁ISBNから', isbn13: isbn);
      fakeGoogle.onSearch = (_) => [_book(title: 'Google')];

      final results = await service.search('4000000000');

      expect(results.length, 1);
      expect(results.first.title, '10桁ISBNから');
    });

    test(
        'should fall back to Google when query is ISBN but OpenBD returns null',
        () async {
      fakeRakuten.onSearch = (_) => [];
      fakeOpenbd.onLookupByIsbn = (_) => null;
      fakeGoogle.onSearch = (_) => [_book(id: 'g1', title: 'Googleフォールバック')];

      final results = await service.search('9784000000000');

      expect(results.length, 1);
      expect(results.first.title, 'Googleフォールバック');
    });

    test('should skip OpenBD and go straight to Google when query is NOT ISBN',
        () async {
      fakeRakuten.onSearch = (_) => [];
      // If OpenBD is called for non-ISBN, it would be a bug
      fakeOpenbd.onLookupByIsbn = (_) =>
          throw Exception('OpenBD should not be called for non-ISBN query');
      fakeGoogle.onSearch = (_) => [_book(id: 'g2', title: 'Google直接')];

      final results = await service.search('普通のキーワード');

      expect(results.length, 1);
      expect(results.first.title, 'Google直接');
    });

    test('should return empty list when all sources fail', () async {
      fakeRakuten.onSearch = (_) => [];
      fakeOpenbd.onLookupByIsbn = (_) => null;
      fakeGoogle.onSearch = (_) => [];

      final results = await service.search('絶対に見つからない本XYZ');

      expect(results, isEmpty);
    });

    test(
        'should skip OpenBD when query has hyphens and spaces (non-ISBN by pattern)',
        () async {
      // Query with hyphens looks like ISBN-style but cleaning is needed
      fakeRakuten.onSearch = (_) => [];
      fakeOpenbd.onLookupByIsbn =
          (_) => _book(id: 'obd-clean', title: 'OpenBD via cleaned ISBN');
      fakeGoogle.onSearch = (_) => [];

      final results = await service.search('978-4-00-000000-0');

      // After cleaning, it becomes '9784000000000' which is a 13-digit ISBN
      expect(results.length, 1);
      expect(results.first.title, 'OpenBD via cleaned ISBN');
    });

    test('should clean hyphens and spaces for ISBN detection', () async {
      fakeRakuten.onSearch = (_) => [];
      fakeOpenbd.onLookupByIsbn = (isbn) {
        // Verify the cleaned ISBN is passed to OpenBD
        expect(isbn, '9784000000000');
        return _book(id: 'clean', title: 'Clean');
      };
      fakeGoogle.onSearch = (_) => [];

      await service.search('978-4-00-000000-0');
    });
  });

  // ━━━━━ lookupByIsbn ━━━━━

  group('BookSearchService.lookupByIsbn', () {
    test('should try Rakuten (isbnjan) first', () async {
      fakeRakuten.onLookupByIsbn = (_) => _book(id: 'r-isbn', title: '楽天から');
      fakeOpenbd.onLookupByIsbn = (_) => _book(title: 'OpenBDから');
      fakeGoogle.onLookupByIsbn = (_) => _book(title: 'Googleから');

      final book = await service.lookupByIsbn('9784000000000');

      expect(book, isNotNull);
      expect(book!.title, '楽天から');
    });

    test('should fall back to OpenBD when Rakuten returns null', () async {
      fakeRakuten.onLookupByIsbn = (_) => null;
      fakeOpenbd.onLookupByIsbn =
          (_) => _book(id: 'obd-isbn', title: 'OpenBDのISBN');
      fakeGoogle.onLookupByIsbn = (_) => _book(title: 'Google');

      final book = await service.lookupByIsbn('9784000000000');

      expect(book, isNotNull);
      expect(book!.title, 'OpenBDのISBN');
    });

    test('should fall back to Google when Rakuten and OpenBD both return null',
        () async {
      fakeRakuten.onLookupByIsbn = (_) => null;
      fakeOpenbd.onLookupByIsbn = (_) => null;
      fakeGoogle.onLookupByIsbn =
          (_) => _book(id: 'g-isbn', title: 'GoogleのISBN');

      final book = await service.lookupByIsbn('9784000000000');

      expect(book, isNotNull);
      expect(book!.title, 'GoogleのISBN');
    });

    test('should return null when all sources return null', () async {
      fakeRakuten.onLookupByIsbn = (_) => null;
      fakeOpenbd.onLookupByIsbn = (_) => null;
      fakeGoogle.onLookupByIsbn = (_) => null;

      final book = await service.lookupByIsbn('0000000000000');

      expect(book, isNull);
    });
  });

  // ━━━━━ ISBN detection ━━━━━

  group('ISBN detection', () {
    test('should detect 13-digit ISBN', () {
      expect(BookSearchService.isIsbn('9784000000000'), true);
    });

    test('should detect 10-digit ISBN', () {
      expect(BookSearchService.isIsbn('4000000000'), true);
    });

    test('should detect ISBN after cleaning hyphens and spaces', () {
      expect(BookSearchService.isIsbn('978-4-00-000000-0'), true);
      expect(BookSearchService.isIsbn('4 000000 000'), true);
    });

    test('should reject non-ISBN strings', () {
      expect(BookSearchService.isIsbn('普通のキーワード'), false);
      expect(BookSearchService.isIsbn('abc'), false);
      expect(BookSearchService.isIsbn(''), false);
      expect(BookSearchService.isIsbn('12345'), false);
      expect(BookSearchService.isIsbn('123456789'), false); // 9 digits
      expect(BookSearchService.isIsbn('12345678901234'), false); // 14 digits
    });
  });
}
