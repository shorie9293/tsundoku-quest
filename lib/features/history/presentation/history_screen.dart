import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/widgets/dungeon_background.dart';
import '../../../../shared/providers/adventurer_provider.dart';
import '../../../../shared/providers/derived_provider.dart';
import '../data/weekly_reading_provider.dart';
import '../data/reading_notes_provider.dart';
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
      body: DungeonBackground(screenType: ScreenType.history,
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

          // Reading notes section
          const _ReadingNotesSection(),
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

/// 読書感想・メモセクション
class _ReadingNotesSection extends ConsumerWidget {
  const _ReadingNotesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(readingNotesProvider);

    return Container(
      key: AppKeys.readingNotesSection,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📝 読書感想・メモ',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          if (notes.isEmpty || notes.every((n) => !n.hasContent))
            const _EmptyNotesPlaceholder()
          else
            ListView.builder(
              key: AppKeys.readingNotesList,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return _NoteCard(note: note);
              },
            ),
        ],
      ),
    );
  }
}

/// 感想がない場合のプレースホルダ
class _EmptyNotesPlaceholder extends StatelessWidget {
  const _EmptyNotesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: AppKeys.readingNotesEmpty,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const Text('✍️',
                style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            const Text('感想を書いてみよう',
                style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            const Text(
              '読了時に学びを記録すると、ここに表示されます',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 個別の感想カード
class _NoteCard extends StatelessWidget {
  final ReadingNoteItem note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final title = note.bookTitle ?? '不明な本';
    final date = note.createdAt.length >= 10
        ? note.createdAt.substring(0, 10)
        : note.createdAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
              ),
              Text(date,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          ...note.learnings
              .where((l) => l.isNotEmpty)
              .map((learning) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡 ',
                            style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Text(learning,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textPrimary)),
                        ),
                      ],
                    ),
                  )),
          if (note.action.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎯 ',
                    style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Text(note.action,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary)),
                ),
              ],
            ),
          ],
          if (note.favoriteQuote != null &&
              note.favoriteQuote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📜 ',
                    style: const TextStyle(fontSize: 12)),
                Expanded(
                  child: Text('"${note.favoriteQuote}"',
                      style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
