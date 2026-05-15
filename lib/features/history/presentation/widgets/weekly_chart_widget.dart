import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// 週間読書量グラフWidget
///
/// 直近7日間の読書時間（分）を棒グラフで表示する。
class WeeklyChartWidget extends StatelessWidget {
  final List<int> weeklyMinutes;

  const WeeklyChartWidget({super.key, required this.weeklyMinutes});

  @override
  Widget build(BuildContext context) {
    final totalMinutes = weeklyMinutes.fold<int>(0, (sum, m) => sum + m);
    final maxMinutes = weeklyMinutes.reduce((a, b) => a > b ? a : b);

    final now = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
      return weekdays[date.weekday - 1];
    });

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
          const Text('📊 週間読書',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('今週の合計: $totalMinutes分',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final barHeight = maxMinutes > 0
                    ? (weeklyMinutes[i] / maxMinutes) * 60.0
                    : 0.0;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: barHeight.clamp(2.0, 60.0),
                        decoration: BoxDecoration(
                          color: _barColor(i),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                        ),
                        width: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayLabels[i],
                        style: const TextStyle(
                            fontSize: 9, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Color _barColor(int dayIndex) {
    if (dayIndex == 6) return AppTheme.progress;
    return AppTheme.active.withAlpha(120);
  }
}
