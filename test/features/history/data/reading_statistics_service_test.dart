import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book_shelf.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/history/data/reading_statistics_service.dart';

UserBook _ub({
  required String id,
  String? completedAt,
  int pages = 300,
}) {
  final book = Book(
    id: 'book-$id',
    title: 'Book $id',
    source: BookSource.manual,
    createdAt: '2026-01-01T00:00:00Z',
  );
  return UserBook(
    id: id,
    userId: 'u1',
    bookId: 'book-$id',
    book: book,
    status: completedAt != null ? BookStatus.completed : BookStatus.reading,
    medium: BookMedium.physical,
    currentPage: pages,
    completedAt: completedAt,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  group('ReadingStatisticsService monthly', () {
    test('直近N月にゼロ埋めで月別読了数・ページ数を集計する', () {
      final books = [
        _ub(id: 'a', completedAt: '2026-09-05T10:00:00Z', pages: 200),
        _ub(id: 'b', completedAt: '2026-09-20T10:00:00Z', pages: 300),
        _ub(id: 'c', completedAt: '2026-08-15T10:00:00Z', pages: 100),
        _ub(id: 'd', completedAt: '2026-01-10T10:00:00Z', pages: 500),
      ];
      final now = DateTime(2026, 9, 30);
      final months = ReadingStatisticsService.monthlyCompletions(
        books: books,
        now: now,
        months: 3,
      );
      expect(months.length, 3);
      expect(months[0].label, '2026-07');
      expect(months[0].count, 0);
      expect(months[0].pages, 0);
      expect(months[1].label, '2026-08');
      expect(months[1].count, 1);
      expect(months[1].pages, 100);
      expect(months[2].label, '2026-09');
      expect(months[2].count, 2);
      expect(months[2].pages, 500);
    });

    test('年跨ぎ: nowが1月なら前年月を含む', () {
      final books = [
        _ub(id: 'x', completedAt: '2025-12-20T10:00:00Z', pages: 120),
      ];
      final months = ReadingStatisticsService.monthlyCompletions(
        books: books,
        now: DateTime(2026, 1, 15),
        months: 2,
      );
      expect(months[0].label, '2025-12');
      expect(months[0].count, 1);
      expect(months[1].label, '2026-01');
      expect(months[1].count, 0);
    });

    test('読了日が無い本・月外の本は集計外', () {
      final books = [
        _ub(id: 'a', completedAt: null),
        _ub(id: 'b', completedAt: 'not-a-date'),
        _ub(id: 'c', completedAt: '2025-01-01T00:00:00Z'),
      ];
      final months = ReadingStatisticsService.monthlyCompletions(
        books: books,
        now: DateTime(2026, 9, 1),
        months: 3,
      );
      expect(months.every((m) => m.count == 0), isTrue);
    });

    test('months < 1 は空', () {
      final months = ReadingStatisticsService.monthlyCompletions(
        books: const [],
        now: DateTime(2026, 9, 1),
        months: 0,
      );
      expect(months, isEmpty);
    });

    test('月内合計・読了数のサマリを返す', () {
      final books = [
        _ub(id: 'a', completedAt: '2026-09-05T10:00:00Z', pages: 200),
        _ub(id: 'b', completedAt: '2026-08-15T10:00:00Z', pages: 100),
      ];
      final summary = ReadingStatisticsService.summarizeMonthly(
        books: books,
        now: DateTime(2026, 9, 30),
        months: 1,
      );
      expect(summary.currentCount, 1);
      expect(summary.currentPages, 200);
      expect(summary.bestCount, 1);
      expect(summary.bestLabel, '2026-09');
      expect(summary.windowCount, 1);
      expect(summary.windowPages, 200);
    });
  });

  group('ReadingStatisticsService yearly', () {
    test('年別読了数を降順で集計する', () {
      final books = [
        _ub(id: 'a', completedAt: '2026-09-05T10:00:00Z'),
        _ub(id: 'b', completedAt: '2026-03-01T10:00:00Z'),
        _ub(id: 'c', completedAt: '2025-07-11T10:00:00Z'),
        _ub(id: 'd', completedAt: null),
      ];
      final years = ReadingStatisticsService.yearlyCompletions(
        books: books,
        now: DateTime(2026, 9, 1),
        years: 2,
      );
      expect(years.length, 2);
      expect(years[0].label, '2026');
      expect(years[0].count, 2);
      expect(years[1].label, '2025');
      expect(years[1].count, 1);
    });
  });

  group('ReadingStatisticsService byShelf', () {
    test('棚ごとの読了数・進行中数を集計する', () {
      final books = [
        _ub(id: 'a', completedAt: '2026-09-05T10:00:00Z', pages: 200),
        _ub(id: 'b', completedAt: null, pages: 50),
        _ub(id: 'c', completedAt: '2026-02-01T10:00:00Z', pages: 90),
      ];
      final shelves = [
        const BookShelf(
            id: 's1',
            name: '技術書',
            colorValue: 1,
            createdAt: '2026-01-01',
            userBookIds: ['a', 'b']),
        const BookShelf(
            id: 's2',
            name: '小説',
            colorValue: 2,
            createdAt: '2026-01-02',
            userBookIds: ['c']),
      ];
      final cats = ReadingStatisticsService.byShelf(
        books: books,
        shelves: shelves,
      );
      expect(cats.length, 2);
      final s1 = cats.firstWhere((c) => c.label == '技術書');
      expect(s1.completedCount, 1);
      expect(s1.inProgressCount, 1);
      expect(s1.totalCount, 2);
      final s2 = cats.firstWhere((c) => c.label == '小説');
      expect(s2.completedCount, 1);
      expect(s2.inProgressCount, 0);
      expect(s2.totalCount, 1);
    });

    test('空棚も0件で表示される', () {
      final cats = ReadingStatisticsService.byShelf(
        books: const [],
        shelves: const [
          BookShelf(id: 's1', name: '空棚', colorValue: 1, createdAt: 'c'),
        ],
      );
      expect(cats.single.label, '空棚');
      expect(cats.single.totalCount, 0);
    });
  });
}