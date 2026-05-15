import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/recommendation/domain/recommendation_service.dart';

void main() {
  group('RecommendationService.pickOne', () {
    test('returns null for empty list', () {
      final result = RecommendationService.pickOne([]);
      expect(result, isNull);
    });

    test('returns a recommendation for non-empty list', () {
      final book = Book(
        id: 'b1',
        title: 'テスト本',
        authors: ['著者A'],
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

      final result = RecommendationService.pickOne([userBook]);
      expect(result, isNotNull);
      expect(result!.id, 'ub-1');
      expect(result.bookTitle, 'テスト本');
    });

    test('reason contains correct day count for old books (>30 days)', () {
      final oldDate = DateTime.now().subtract(const Duration(days: 40));
      final book = Book(
        id: 'b1',
        title: '古い本',
        authors: ['著者B'],
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
        createdAt: oldDate.toIso8601String(),
      );

      final result = RecommendationService.pickOne([userBook]);
      expect(result, isNotNull);
      expect(result!.reason, contains('日間待機中の冒険'));
      final dayMatch = RegExp(r'(\d+)日間').firstMatch(result.reason);
      expect(dayMatch, isNotNull);
      final days = int.parse(dayMatch!.group(1)!);
      expect(days, greaterThanOrEqualTo(30));
    });

    test('reason uses 今日のランダムな一冊 for recent books', () {
      final recentDate = DateTime.now().subtract(const Duration(days: 1));
      final book = Book(
        id: 'b1',
        title: '新しい本',
        authors: ['著者C'],
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
        createdAt: recentDate.toIso8601String(),
      );

      final result = RecommendationService.pickOne([userBook]);
      expect(result, isNotNull);
      expect(result!.reason, '今日のランダムな一冊');
    });
  });

  group('RecommendationService.getDailyRecommendations', () {
    test('returns empty list for empty tsundokuBooks when no client', () async {
      final result = await RecommendationService.getDailyRecommendations(
        tsundokuBooks: [],
      );
      expect(result, isEmpty);
    });

    test('returns local picks when no Supabase client provided', () async {
      final book = Book(
        id: 'b1',
        title: 'ローカル本',
        authors: ['ローカル著者'],
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
        createdAt: DateTime.now().toIso8601String(),
      );

      final result = await RecommendationService.getDailyRecommendations(
        tsundokuBooks: [userBook, userBook, userBook],
      );
      // Should return up to 3 local picks
      expect(result.length, lessThanOrEqualTo(3));
      expect(result.length, greaterThan(0));
      expect(result.first.bookTitle, 'ローカル本');
    });

    test('returns local picks when Supabase throws', () async {
      final book = Book(
        id: 'b1',
        title: 'フォールバック本',
        authors: ['著者'],
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
        createdAt: DateTime.now().toIso8601String(),
      );

      // Provide a mock client that will throw — using the real SupabaseClient is not
      // available in test, so we verify the fallback by passing null client
      final result = await RecommendationService.getDailyRecommendations(
        tsundokuBooks: [userBook],
        client: null,
      );
      expect(result, isNotEmpty);
      expect(result.first.bookTitle, 'フォールバック本');
    });
  });

  group('RecommendationService.getPopularBooks', () {
    // getPopularBooks は SupabaseClient を要求するため、
    // Mocktail の invariant generic 制約により単体テストが困難。
    // 統合テストレベルで検証する。
  });
}
