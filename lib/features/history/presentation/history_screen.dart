import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/widgets/dungeon_background.dart';
import '../../../../shared/providers/adventurer_provider.dart';
import '../../../../shared/providers/derived_provider.dart';
import '../data/weekly_reading_provider.dart';
import 'widgets/reading_calendar_widget.dart';
import 'widgets/weekly_chart_widget.dart';

/// 足跡画面（統計）
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adventurer = ref.watch(adventurerProvider);
    final stats = ref.watch(bookStatsProvider);

    return Scaffold(
      key: AppKeys.historyScreen,
      appBar: AppBar(title: const Text('📊 足跡')),
      body: DungeonBackground(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Monthly stats grid
          GridView.count(
            key: AppKeys.monthlyStatsGrid,
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _StatCard(
                  icon: '📚',
                  label: '登録数',
                  value: '${adventurer.totalBooksRegistered}'),
              _StatCard(
                  icon: '✅',
                  label: '読了数',
                  value: '${adventurer.totalBooksCompleted}'),
              _StatCard(
                  icon: '⏱',
                  label: '読書時間',
                  value: '${adventurer.totalReadingMinutes}分'),
              _StatCard(
                  icon: '📄',
                  label: '総ページ',
                  value: '${adventurer.totalPagesRead}'),
              _StatCard(
                  icon: '🔥',
                  label: '連続日数',
                  value: '${adventurer.currentStreak}日'),
              _StatCard(
                  icon: '📖',
                  label: '読了率',
                  value: '${(stats.completionRate * 100).toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 24),

          // Level info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('⚔️', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lv.${adventurer.level} ${adventurer.title}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.active)),
                        Text(
                            '${adventurer.xp} / ${adventurer.xpToNextLevel} XP',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: adventurer.xpToNextLevel > 0
                        ? adventurer.xp / adventurer.xpToNextLevel
                        : 0,
                    backgroundColor: AppTheme.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.progress),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Reading calendar
          const ReadingCalendarWidget(key: AppKeys.readingCalendar),
          const SizedBox(height: 16),

          // Weekly reading chart
          ref.watch(weeklyReadingMinutesProvider).when(
            data: (weeklyMinutes) =>
                WeeklyChartWidget(weeklyMinutes: weeklyMinutes),
            loading: () => const SizedBox(height: 120),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Stats summary
          if (adventurer.totalReadingMinutes > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📈 平均',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  _StatRow(
                      label: '1日あたりの読書時間',
                      value:
                          '${(adventurer.totalReadingMinutes / adventurer.currentStreak.clamp(1, 999)).toStringAsFixed(0)}分'),
                  _StatRow(
                      label: '1冊あたりのページ数',
                      value: adventurer.totalBooksCompleted > 0
                          ? '${(adventurer.totalPagesRead / adventurer.totalBooksCompleted).toStringAsFixed(0)}p'
                          : 'N/A'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon, label, value;
  const _StatCard(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
