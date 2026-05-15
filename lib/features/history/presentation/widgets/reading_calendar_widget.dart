import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/adventurer_provider.dart';

/// 読書カレンダーWidget
///
/// 今日から過去30日間の読書状況を7列グリッドで表示する。
class ReadingCalendarWidget extends ConsumerWidget {
  const ReadingCalendarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingDates =
        ref.watch(adventurerProvider.select((stats) => stats.readingDates));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 今日から過去30日分の日付リストを生成
    final dates = List.generate(30, (i) => today.subtract(Duration(days: i)));

    // 読書あり日付のセット（高速検索用）
    final readingDateSet = readingDates.toSet();

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
          const Text('📅 読書カレンダー',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          // 凡例
          const Row(
            children: [
              _LegendItem(color: Colors.green, label: '読書あり'),
              SizedBox(width: 16),
              _LegendItem(color: AppTheme.progress, label: '今日'),
            ],
          ),
          const SizedBox(height: 8),
          // 30日間グリッド
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
            children: dates.map((date) {
              final dateStr =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final isReadingDay = readingDateSet.contains(dateStr);
              final isToday = date == today;

              Color bgColor;
              Color borderColor;
              double borderWidth = 1;

              if (isReadingDay || isToday) {
                if (isToday && isReadingDay) {
                  // 今日が読書日の場合 → progress色優先
                  bgColor = AppTheme.progress.withAlpha(80);
                  borderColor = AppTheme.progress;
                  borderWidth = 2;
                } else if (isToday) {
                  bgColor = AppTheme.progress.withAlpha(80);
                  borderColor = AppTheme.progress;
                  borderWidth = 2;
                } else {
                  bgColor = Colors.green.withAlpha(60);
                  borderColor = Colors.green.withAlpha(120);
                }
              } else {
                bgColor = AppTheme.cardBackground;
                borderColor = AppTheme.border;
              }

              return Container(
                key: ValueKey('calendar_cell_$dateStr'),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${date.day}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 凡例アイテム
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withAlpha(80),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
