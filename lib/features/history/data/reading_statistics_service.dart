import 'package:tsundoku_quest/domain/models/book_shelf.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';

/// 月別・年別・棚別の読書統計を集計する純粋ロジックサービス
///
/// Widget / Hive / Riverpod に依存せず、引数のリストからのみ集計する。
/// 不正な日付・月外の本は黙って集計外とする（統計で例外を投げない）。
class ReadingStatisticsService {
  const ReadingStatisticsService._();

  /// 月別の読了集計（直近 [months] ヶ月・古い順・ゼロ埋め）
  static List<MonthlyBucket> monthlyCompletions({
    required List<UserBook> books,
    required DateTime now,
    int months = 12,
  }) {
    if (months < 1) return const [];
    final labels = <String>[];
    final counts = <int>[];
    final pages = <int>[];
    for (var i = months - 1; i >= 0; i--) {
      labels.add(_monthKey(DateTime(now.year, now.month - i)));
      counts.add(0);
      pages.add(0);
    }
    final index = {for (var i = 0; i < labels.length; i++) labels[i]: i};
    for (final ub in books) {
      final dt = _parse(ub.completedAt);
      if (dt == null) continue;
      final i = index[_monthKey(dt)];
      if (i == null) continue;
      counts[i] += 1;
      pages[i] += ub.currentPage;
    }
    return [
      for (var i = 0; i < labels.length; i++)
        MonthlyBucket(label: labels[i], count: counts[i], pages: pages[i]),
    ];
  }

  /// 現在月の実績と窓全体のサマリ
  static MonthlySummary summarizeMonthly({
    required List<UserBook> books,
    required DateTime now,
    int months = 12,
  }) {
    final buckets = monthlyCompletions(
      books: books,
      now: now,
      months: months,
    );
    if (buckets.isEmpty) {
      return const MonthlySummary(
        currentCount: 0,
        currentPages: 0,
        bestCount: 0,
        bestLabel: '',
        windowCount: 0,
        windowPages: 0,
      );
    }
    final current = buckets.last;
    final best = buckets.reduce((a, b) => b.count > a.count ? b : a);
    return MonthlySummary(
      currentCount: current.count,
      currentPages: current.pages,
      bestCount: best.count,
      bestLabel: best.label,
      windowCount: buckets.fold<int>(0, (s, b) => s + b.count),
      windowPages: buckets.fold<int>(0, (s, b) => s + b.pages),
    );
  }

  /// 年別の読了集計（直近 [years] 年・新しい順・ゼロ埋め）
  static List<YearlyBucket> yearlyCompletions({
    required List<UserBook> books,
    required DateTime now,
    int years = 3,
  }) {
    if (years < 1) return const [];
    final counts = <int, int>{};
    for (var i = years - 1; i >= 0; i--) {
      counts[now.year - i] = 0;
    }
    for (final ub in books) {
      final dt = _parse(ub.completedAt);
      if (dt == null) continue;
      if (counts.containsKey(dt.year)) {
        counts[dt.year] = counts[dt.year]! + 1;
      }
    }
    return [
      for (final y in counts.keys.toList()..sort((a, b) => b.compareTo(a)))
        YearlyBucket(label: '$y', count: counts[y]!),
    ];
  }

  /// 棚別（自作棚をジャンル軸として活用）の蔵書集計
  static List<ShelfCategory> byShelf({
    required List<UserBook> books,
    required List<BookShelf> shelves,
  }) {
    final byId = {for (final ub in books) ub.id: ub};
    return [
      for (final shelf in shelves)
        () {
          final members = [
            for (final id in shelf.userBookIds)
              if (byId[id] != null) byId[id]!,
          ];
          return ShelfCategory(
            label: shelf.name,
            totalCount: members.length,
            completedCount: members
                .where((ub) => ub.status == BookStatus.completed)
                .length,
            inProgressCount: members
                .where((ub) => ub.status == BookStatus.reading)
                .length,
          );
        }(),
    ];
  }

  static String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static DateTime? _parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso)?.toUtc();
  }
}

/// 月別バケット（label は 'YYYY-MM'）
class MonthlyBucket {
  final String label;
  final int count;
  final int pages;

  const MonthlyBucket({
    required this.label,
    required this.count,
    required this.pages,
  });
}

/// 月次サマリ
class MonthlySummary {
  /// 現在月の読了数
  final int currentCount;

  /// 現在月の読了ページ数
  final int currentPages;

  /// 窓内で最も読んだ月の読了数
  final int bestCount;

  /// 窓内で最も読んだ月（'YYYY-MM'）
  final String bestLabel;

  /// 窓全体の読了数
  final int windowCount;

  /// 窓全体の読了ページ数
  final int windowPages;

  const MonthlySummary({
    required this.currentCount,
    required this.currentPages,
    required this.bestCount,
    required this.bestLabel,
    required this.windowCount,
    required this.windowPages,
  });
}

/// 年別バケット（label は 'YYYY'）
class YearlyBucket {
  final String label;
  final int count;

  const YearlyBucket({required this.label, required this.count});
}

/// 棚別集計
class ShelfCategory {
  final String label;
  final int totalCount;
  final int completedCount;
  final int inProgressCount;

  const ShelfCategory({
    required this.label,
    required this.totalCount,
    required this.completedCount,
    required this.inProgressCount,
  });
}