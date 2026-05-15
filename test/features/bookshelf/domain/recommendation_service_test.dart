import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/recommendation_service.dart';

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
      // Create a book from 40 days ago
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
      // Should contain "日間待機中の冒険" and a day count >= 30
      expect(result!.reason, contains('日間待機中の冒険'));
      // Extract the number
      final dayMatch = RegExp(r'(\d+)日間').firstMatch(result.reason);
      expect(dayMatch, isNotNull);
      final days = int.parse(dayMatch!.group(1)!);
      expect(days, greaterThanOrEqualTo(30));
    });

    test('reason uses 今日のランダムな一冊 for recent books', () {
      // Create a book from just 1 day ago
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
}
