import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../data/reading_statistics_provider.dart';

/// 月間/年間・棚別の読書統計ダッシュボード
///
/// 直近12ヶ月の読了数棒グラフ・年別集計・棚別（自作棚をジャンル軸として
/// 活用）集計を表示する。週次チャートと同型の Container 棒グラフで描画し、
/// 新規依存は導入しない。
class ReadingStatisticsDashboard extends ConsumerWidget {
  const ReadingStatisticsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthly = ref.watch(monthlyReadingStatsProvider);
    final summary = ref.watch(monthlyReadingSummaryProvider);
    final yearly = ref.watch(yearlyReadingStatsProvider);
    final shelfCats = ref.watch(shelfCategoryStatsProvider);

    return Column(
      key: AppKeys.readingStatisticsDashboard,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          title: '📆 月間読了',
          subtitle: summary.currentCount > 0
              ? '今月: ${summary.currentCount}冊・${summary.currentPages}ページ'
              : '今月の読了はまだありません',
          child: MonthlyBarChart(buckets: monthly),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: '🗓 年間読了',
          subtitle: '窓計 ${summary.windowCount}冊・${summary.windowPages}ページ',
          child: YearlyRows(buckets: yearly),
        ),
        if (shelfCats.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Panel(
            title: '🗂 棚別の蔵書',
            subtitle: '自作棚ごとの読了/読書中',
            child: ShelfCategoryRows(shelfCategories: shelfCats),
          ),
        ],
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// 月別読了数の棒グラフ（12本・ゼロ月は下限2pxの見えない棒）
class MonthlyBarChart extends StatelessWidget {
  final List buckets;

  const MonthlyBarChart({super.key, required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxCount =
        buckets.fold<int>(0, (m, b) => b.count > m ? b.count : m);
    return SizedBox(
      key: AppKeys.readingStatisticsMonthlyChart,
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in buckets)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (b.count > 0)
                    Text('${b.count}',
                        style: const TextStyle(
                            fontSize: 9, color: AppTheme.textPrimary)),
                  Container(
                    height: maxCount > 0
                        ? (b.count / maxCount * 60.0).clamp(2.0, 60.0)
                        : 2.0,
                    decoration: BoxDecoration(
                      color: b.count > 0
                          ? AppTheme.calendarToday
                          : AppTheme.border,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3)),
                    ),
                    width: 18,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b.label.substring(5), // 'MM' 部分
                    style: const TextStyle(
                        fontSize: 9, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 年別読了数の行表示
class YearlyRows extends StatelessWidget {
  final List buckets;

  const YearlyRows({super.key, required this.buckets});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: AppKeys.readingStatisticsYearlyRows,
      children: [
        for (final y in buckets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(y.label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                ),
                Expanded(
                  child: Text('${y.count}冊',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 棚別蔵書の行表示
class ShelfCategoryRows extends StatelessWidget {
  final List shelfCategories;

  const ShelfCategoryRows({super.key, required this.shelfCategories});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: AppKeys.readingStatisticsShelfRows,
      children: [
        for (final c in shelfCategories)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(c.label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                ),
                Text(
                  '読了${c.completedCount}・読書中${c.inProgressCount}・計${c.totalCount}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}