import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';

void main() {
  group('UserBook.fromSupabase', () {
    test('should parse Supabase JSON with joined book', () {
      final json = {
        'id': 'ub-1',
        'user_id': 'user-1',
        'book_id': 'book-1',
        'book': {
          'id': 'book-1',
          'title': 'テストの本',
          'authors': ['著者'],
          'source': 'rakuten',
          'createdAt': '2026-01-01T00:00:00Z',
        },
        'status': 'reading',
        'medium': 'physical',
        'current_page': 42,
        'total_reading_minutes': 120,
        'rating': 4,
        'started_at': '2026-05-01T10:00:00Z',
        'completed_at': null,
        'notes': '面白い',
        'created_at': '2026-05-01T09:00:00Z',
      };

      final userBook = UserBook.fromSupabase(json);

      expect(userBook.id, 'ub-1');
      expect(userBook.userId, 'user-1');
      expect(userBook.bookId, 'book-1');
      expect(userBook.book, isNotNull);
      expect(userBook.book!.title, 'テストの本');
      expect(userBook.status, BookStatus.reading);
      expect(userBook.medium, BookMedium.physical);
      expect(userBook.currentPage, 42);
      expect(userBook.totalReadingMinutes, 120); // Supabaseから正しく読み込める
      expect(userBook.rating, 4);
      expect(userBook.startedAt, '2026-05-01T10:00:00Z');
      expect(userBook.completedAt, isNull);
      expect(userBook.notes, '面白い');
      expect(userBook.createdAt, '2026-05-01T09:00:00Z');
    });

    test('should handle minimal Supabase JSON', () {
      final json = {
        'id': 'ub-min',
        'user_id': 'user-1',
        'book_id': 'book-1',
        'status': 'tsundoku',
        'medium': 'ebook',
        'created_at': '2026-01-01T00:00:00Z',
      };

      final userBook = UserBook.fromSupabase(json);

      expect(userBook.id, 'ub-min');
      expect(userBook.userId, 'user-1');
      expect(userBook.bookId, 'book-1');
      expect(userBook.book, isNull);
      expect(userBook.currentPage, 0);
      expect(userBook.rating, isNull);
      expect(userBook.startedAt, isNull);
      expect(userBook.completedAt, isNull);
      expect(userBook.notes, isNull);
    });

    test('should parse JSON without joined book', () {
      final json = {
        'id': 'ub-2',
        'user_id': 'user-2',
        'book_id': 'book-2',
        'status': 'completed',
        'medium': 'audiobook',
        'current_page': 300,
        'rating': 5,
        'started_at': '2026-03-01T00:00:00Z',
        'completed_at': '2026-04-15T00:00:00Z',
        'notes': '名著',
        'created_at': '2026-03-01T00:00:00Z',
      };

      final userBook = UserBook.fromSupabase(json);

      expect(userBook.id, 'ub-2');
      expect(userBook.userId, 'user-2');
      expect(userBook.status, BookStatus.completed);
      expect(userBook.medium, BookMedium.audiobook);
      expect(userBook.currentPage, 300);
      expect(userBook.rating, 5);
      expect(userBook.startedAt, '2026-03-01T00:00:00Z');
      expect(userBook.completedAt, '2026-04-15T00:00:00Z');
      expect(userBook.notes, '名著');
      expect(userBook.createdAt, '2026-03-01T00:00:00Z');
    });
  });

  group('UserBook.toSupabase', () {
    test('should serialize to Supabase-compatible Map', () {
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

      final map = userBook.toSupabase();

      expect(map['id'], 'ub-2');
      expect(map['user_id'], 'user-2');
      expect(map['book_id'], 'book-2');
      expect(map['status'], 'completed');
      expect(map['medium'], 'audiobook');
      expect(map['current_page'], 300);
      expect(map['rating'], 5);
      expect(map['started_at'], '2026-03-01T00:00:00Z');
      expect(map['completed_at'], '2026-04-15T00:00:00Z');
      expect(map['notes'], '名著');
      expect(map['created_at'], '2026-03-01T00:00:00Z');
      // totalReadingMinutes を Supabase に保存する
      expect(map['total_reading_minutes'], 600);
      // book は含まない
      expect(map.containsKey('book'), false);
      expect(map.containsKey('book_id'), true);
    });

    test('should handle nullable fields correctly', () {
      final userBook = UserBook(
        id: 'ub-3',
        userId: 'user-3',
        bookId: 'book-3',
        status: BookStatus.tsundoku,
        medium: BookMedium.physical,
        createdAt: '2026-05-01T00:00:00Z',
      );

      final map = userBook.toSupabase();

      expect(map['current_page'], 0);
      expect(map['rating'], isNull);
      expect(map['started_at'], isNull);
      expect(map['completed_at'], isNull);
      expect(map['notes'], isNull);
    });
  });

  group('UserBook — fromSupabase → toSupabase ラウンドトリップ', () {
    test('should round-trip Supabase JSON without book', () {
      final original = {
        'id': 'ub-rt',
        'user_id': 'user-rt',
        'book_id': 'book-rt',
        'status': 'reading',
        'medium': 'ebook',
        'current_page': 100,
        'total_reading_minutes': 60,
        'rating': 3,
        'started_at': '2026-06-01T00:00:00Z',
        'completed_at': null,
        'notes': 'ラウンドトリップテスト',
        'created_at': '2026-06-01T00:00:00Z',
      };

      final userBook = UserBook.fromSupabase(original);
      final exported = userBook.toSupabase();

      // ラウンドトリップで同じキーが維持されることを確認
      for (final key in original.keys) {
        if (key == 'book') continue; // bookはtoSupabaseに含まれない
        expect(exported[key], original[key],
            reason: 'Key $key should match after round-trip');
      }
    });
  });
}
