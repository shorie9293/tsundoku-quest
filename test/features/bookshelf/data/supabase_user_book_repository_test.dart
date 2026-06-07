import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/repositories/user_book_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/supabase_user_book_repository.dart';

/// Helper: Supabase形式のJSON行（スネークケース）を作成
Map<String, dynamic> ubJson(String id, String status, {String? bookId}) {
  return {
    'id': id,
    'user_id': 'user-1',
    'book_id': bookId ?? 'book-$id',
    'status': status,
    'medium': 'physical',
    'current_page': 0,
    'total_reading_minutes': 0,
    'created_at': '2026-05-04T10:00:00Z',
  };
}

/// テスト用: executeQuery をオーバーライドして制御されたデータを返す
class _TestableUserBookRepository extends SupabaseUserBookRepository {
  dynamic _nextResult;

  _TestableUserBookRepository() : super(_dummyClient());

  static SupabaseClient _dummyClient() =>
      SupabaseClient('https://test.supabase.co', 'test-key');

  void setResult(dynamic result) => _nextResult = result;

  @override
  Future<dynamic> executeQuery(
    String table,
    Object? Function(SupabaseQueryBuilder) buildQuery,
  ) async {
    return _nextResult;
  }
}

void main() {
  late _TestableUserBookRepository repo;

  setUp(() {
    repo = _TestableUserBookRepository();
  });

  group('implements UserBookRepository', () {
    test('implements interface', () {
      expect(repo, isA<UserBookRepository>());
    });
  });

  group('getMyBooks', () {
    test('returns list of UserBooks from JSON rows', () async {
      repo.setResult([
        ubJson('ub-1', 'tsundoku'),
        ubJson('ub-2', 'reading'),
      ]);

      final books = await repo.getMyBooks();
      expect(books.length, 2);
      expect(books[0].id, 'ub-1');
      expect(books[1].id, 'ub-2');
    });

    test('returns empty list when no books', () async {
      repo.setResult(<Map<String, dynamic>>[]);

      expect(await repo.getMyBooks(), isEmpty);
    });
  });

  group('getByStatus', () {
    test('filters by tsundoku status', () async {
      repo.setResult([
        ubJson('ub-1', 'tsundoku'),
      ]);

      final books = await repo.getByStatus(BookStatus.tsundoku);
      expect(books.length, 1);
      expect(books[0].id, 'ub-1');
    });

    test('filters by reading status', () async {
      repo.setResult([
        ubJson('ub-2', 'reading'),
      ]);

      final books = await repo.getByStatus(BookStatus.reading);
      expect(books.length, 1);
      expect(books[0].status, BookStatus.reading);
    });

    test('returns empty when no books match status', () async {
      repo.setResult(<Map<String, dynamic>>[]);

      expect(await repo.getByStatus(BookStatus.completed), isEmpty);
    });
  });

  group('getById', () {
    test('returns UserBook when found', () async {
      repo.setResult(ubJson('ub-1', 'tsundoku'));

      final book = await repo.getById('ub-1');
      expect(book, isNotNull);
      expect(book!.id, 'ub-1');
    });

    test('returns null when not found', () async {
      repo.setResult(null);

      expect(await repo.getById('nonexistent'), isNull);
    });
  });

  group('bookToSupabase conversion', () {
    test('converts Book with all fields to Supabase format', () {
      const book = Book(
        id: 'b-1',
        isbn13: '9781234567890',
        isbn10: '1234567890',
        title: 'Dart Programming',
        authors: ['John Doe', 'Jane Smith'],
        publisher: 'TechPress',
        publishedDate: '2024-01-15',
        description: 'A book about Dart',
        pageCount: 300,
        coverImageUrl: 'https://example.com/cover.jpg',
        source: BookSource.openbd,
        createdAt: '2026-01-01T00:00:00Z',
      );

      final result = repo.bookToSupabase(book);

      expect(result['id'], 'b-1');
      expect(result['isbn13'], '9781234567890');
      expect(result['isbn10'], '1234567890');
      expect(result['title'], 'Dart Programming');
      expect(result['authors'], ['John Doe', 'Jane Smith']);
      expect(result['publisher'], 'TechPress');
      expect(result['published_date'], '2024-01-15');
      expect(result['description'], 'A book about Dart');
      expect(result['page_count'], 300);
      expect(result['cover_image_url'], 'https://example.com/cover.jpg');
      expect(result['source'], 'openbd');
      expect(result['created_at'], '2026-01-01T00:00:00Z');
    });

    test('converts Book with minimal fields', () {
      const book = Book(
        id: 'b-2',
        title: 'Minimal Book',
        authors: [],
        source: BookSource.manual,
        createdAt: '2026-02-01T00:00:00Z',
      );

      final result = repo.bookToSupabase(book);

      expect(result['id'], 'b-2');
      expect(result['title'], 'Minimal Book');
      expect(result['authors'], isEmpty);
      expect(result['source'], 'manual');
      expect(result['isbn13'], isNull);
      expect(result['page_count'], isNull);
    });
  });

  group('crud operations', () {
    test('deleteBook calls executeQuery', () async {
      repo.setResult(null); // delete returns void

      // Should not throw
      await expectLater(repo.deleteBook('ub-1'), completes);
    });
  });
}
