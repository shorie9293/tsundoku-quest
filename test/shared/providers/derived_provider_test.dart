import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';
import 'package:tsundoku_quest/shared/providers/derived_provider.dart';

BookDataNotifier _setupNotifierWithBooks() {
  final notifier = BookDataNotifier();
  // 積読2冊
  notifier.addUserBook(UserBook(
    id: 'ub-1',
    userId: 'u1',
    bookId: 'b1',
    status: BookStatus.tsundoku,
    medium: BookMedium.physical,
    createdAt: '2026-01-01T00:00:00Z',
  ));
  notifier.addUserBook(UserBook(
    id: 'ub-2',
    userId: 'u1',
    bookId: 'b2',
    status: BookStatus.tsundoku,
    medium: BookMedium.ebook,
    createdAt: '2026-02-01T00:00:00Z',
  ));
  // 読書中1冊
  notifier.addUserBook(UserBook(
    id: 'ub-3',
    userId: 'u1',
    bookId: 'b3',
    status: BookStatus.reading,
    medium: BookMedium.physical,
    currentPage: 50,
    totalReadingMinutes: 120,
    createdAt: '2026-03-01T00:00:00Z',
  ));
  // 読了1冊
  notifier.addUserBook(UserBook(
    id: 'ub-4',
    userId: 'u1',
    bookId: 'b4',
    status: BookStatus.completed,
    medium: BookMedium.audiobook,
    totalReadingMinutes: 300,
    rating: 4,
    createdAt: '2026-01-15T00:00:00Z',
    completedAt: '2026-02-15T00:00:00Z',
  ));
  return notifier;
}

void main() {
  group('userBooksByStatusProvider', () {
    test('should filter tsundoku books', () {
      final container = ProviderContainer();
      final notifier = container.read(bookDataProvider.notifier);
      _copyNotifierState(notifier, _setupNotifierWithBooks());

      final tsundoku =
          container.read(userBooksByStatusProvider(BookStatus.tsundoku));
      expect(tsundoku.length, 2);
    });

    test('should filter reading books', () {
      final container = ProviderContainer();
      final notifier = container.read(bookDataProvider.notifier);
      _copyNotifierState(notifier, _setupNotifierWithBooks());

      final reading =
          container.read(userBooksByStatusProvider(BookStatus.reading));
      expect(reading.length, 1);
      expect(reading[0].id, 'ub-3');
    });

    test('should filter completed books', () {
      final container = ProviderContainer();
      final notifier = container.read(bookDataProvider.notifier);
      _copyNotifierState(notifier, _setupNotifierWithBooks());

      final completed =
          container.read(userBooksByStatusProvider(BookStatus.completed));
      expect(completed.length, 1);
      expect(completed[0].id, 'ub-4');
    });
  });

  group('bookStatsProvider', () {
    test('should compute correct stats', () {
      final container = ProviderContainer();
      final notifier = container.read(bookDataProvider.notifier);
      _copyNotifierState(notifier, _setupNotifierWithBooks());

      final stats = container.read(bookStatsProvider);

      expect(stats.totalBooks, 4);
      expect(stats.tsundokuCount, 2);
      expect(stats.readingCount, 1);
      expect(stats.completedCount, 1);
      expect(stats.totalReadingMinutes, 420); // 120 + 300
    });
  });
}

/// テスト用ヘルパー: notifierの状態を別のnotifierにコピー
void _copyNotifierState(BookDataNotifier target, BookDataNotifier source) {
  // 直接stateを操作（テスト用）
  // notifierに直接アクセスできないため、add経由でコピー
  for (final b in source.state.books) {
    target.addBook(b);
  }
  for (final ub in source.state.userBooks) {
    target.addUserBook(ub);
  }
  for (final t in source.state.trophies) {
    target.addTrophy(t);
  }
}
