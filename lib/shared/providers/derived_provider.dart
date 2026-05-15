import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'book_data_provider.dart';

/// ステータス別の蔵書リスト（useUserBooksByStatus 相当）
final userBooksByStatusProvider =
    Provider.family<List<UserBook>, BookStatus>((ref, status) {
  final userBooks = ref.watch(bookDataProvider).userBooks;
  return userBooks.where((ub) => ub.status == status).toList();
});

/// 書庫統計
class BookStats {
  final int totalBooks;
  final int tsundokuCount;
  final int readingCount;
  final int completedCount;
  final int totalReadingMinutes;
  final int totalPages;
  final double completionRate; // 読了率

  const BookStats({
    required this.totalBooks,
    required this.tsundokuCount,
    required this.readingCount,
    required this.completedCount,
    required this.totalReadingMinutes,
    required this.totalPages,
    required this.completionRate,
  });
}

/// 書庫統計プロバイダ（useBookStats 相当）
final bookStatsProvider = Provider<BookStats>((ref) {
  final userBooks = ref.watch(bookDataProvider).userBooks;

  final totalBooks = userBooks.length;
  final tsundokuCount =
      userBooks.where((ub) => ub.status == BookStatus.tsundoku).length;
  final readingCount =
      userBooks.where((ub) => ub.status == BookStatus.reading).length;
  final completedCount =
      userBooks.where((ub) => ub.status == BookStatus.completed).length;
  final totalReadingMinutes = userBooks.fold<int>(
    0,
    (sum, ub) => sum + ub.totalReadingMinutes,
  );
  final totalPages = userBooks.fold<int>(
    0,
    (sum, ub) => sum + ub.currentPage,
  );
  final completionRate = totalBooks > 0 ? completedCount / totalBooks : 0.0;

  return BookStats(
    totalBooks: totalBooks,
    tsundokuCount: tsundokuCount,
    readingCount: readingCount,
    completedCount: completedCount,
    totalReadingMinutes: totalReadingMinutes,
    totalPages: totalPages,
    completionRate: completionRate,
  );
});
