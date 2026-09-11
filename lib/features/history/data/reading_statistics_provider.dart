import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/features/shelves/data/shelf_controller.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

import 'reading_statistics_service.dart';

/// 月別読書統計（直近12ヶ月）を提供するProvider
final monthlyReadingStatsProvider = Provider<List<MonthlyBucket>>((ref) {
  final books = ref.watch(bookDataProvider).userBooks;
  return ReadingStatisticsService.monthlyCompletions(
    books: books,
    now: DateTime.now(),
    months: 12,
  );
});

/// 月次サマリ（直近12ヶ月窓）を提供するProvider
final monthlyReadingSummaryProvider = Provider<MonthlySummary>((ref) {
  final books = ref.watch(bookDataProvider).userBooks;
  return ReadingStatisticsService.summarizeMonthly(
    books: books,
    now: DateTime.now(),
    months: 12,
  );
});

/// 年別読書統計（直近3年）を提供するProvider
final yearlyReadingStatsProvider = Provider<List<YearlyBucket>>((ref) {
  final books = ref.watch(bookDataProvider).userBooks;
  return ReadingStatisticsService.yearlyCompletions(
    books: books,
    now: DateTime.now(),
    years: 3,
  );
});

/// 棚別（ジャンル軸）蔵書統計を提供するProvider
final shelfCategoryStatsProvider = Provider<List<ShelfCategory>>((ref) {
  final books = ref.watch(bookDataProvider).userBooks;
  final shelves = ref.watch(shelfControllerProvider);
  return ReadingStatisticsService.byShelf(books: books, shelves: shelves);
});