import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../domain/models/reading_session.dart';
import '../../data/reading_habit_heatmap_service.dart' as habit;
import '../../data/reading_habit_provider.dart';

/// 読書習慣ヒートマップ（曜日×4時間刻みの6時間帯・7×6グリッド）
///
/// Repository には provider 経由でのみ依存し、Widget/Hive に直接依存しない。
/// 試練からは [sessionsOverride] でセッションを注入できる。
class ReadingHabitHeatmap extends ConsumerWidget {
  const ReadingHabitHeatmap({super.key, this.sessionsOverride});

  final List<ReadingSession>? sessionsOverride;

  /// 濃淡レベル 0..4 の 5 段階パレット（ダンジョン背景に馴染む紫系）
  static const List<Color> _levelColors = [
    Color(0xFF292524), // 0: 記録なし
    Color(0xFF4C3575), // 1: 少
    Color(0xFF6D4FC4), // 2
    Color(0xFF8B5CF6), // 3
    Color(0xFFA78BFA), // 4: 多
  ];

  /// level を 0..4 に clamp してパレット色を返す
  /// （withValues(alpha: 0.15 + level*0.22) は level4 で 1.03 となり
  ///  Color の alpha 範囲アサートに抵触し得るため、表引きに統一する）
  Color _colorOf(int level) => _levelColors[level.clamp(0, 4)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessionsOverride != null) {
      return _buildPanel(context, sessionsOverride!);
    }
    return ref.watch(readingHabitSessionsProvider).when(
          data: (sessions) => _buildPanel(context, sessions),
          loading: () => _buildPanel(context, const []),
          error: (_, __) => _buildPanel(context, const []),
        );
  }

  Widget _buildPanel(BuildContext context, List<ReadingSession> sessions) {
    final heatmap = habit.ReadingHabitHeatmapService.build(sessions: sessions);

    return Container(
      key: AppKeys.readingHabitHeatmap,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🕐 読書のリズム',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(
            heatmap.isEmpty
                ? 'まだ読書の記録がありません'
                : '${heatmap.busiestLabel}・合計 ${heatmap.totalMinutes}分・'
                    '${heatmap.totalSessions}回',
            key: AppKeys.readingHabitBusiest,
            style:
                const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          if (heatmap.isEmpty)
            const Text(
              'まだ読書の記録がありません',
              key: AppKeys.readingHabitEmpty,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            )
          else ...[
            _buildGrid(context, heatmap),
            const SizedBox(height: 8),
            _buildLegend(),
          ],
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, habit.ReadingHabitHeatmap heatmap) {
    return SingleChildScrollView(
      key: AppKeys.readingHabitGrid,
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 時間帯ラベル行（先頭列は空）
          Row(
            children: [
              const SizedBox(width: 24),
              for (var slot = 0;
                  slot < habit.ReadingHabitHeatmapService.slotCount;
                  slot++)
                SizedBox(
                  width: 38,
                  child: Text(
                    habit.ReadingHabitHeatmapService.slotLabel(slot),
                    style: const TextStyle(
                        fontSize: 9, color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
          for (var weekday = 1; weekday <= 7; weekday++)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      habit.ReadingHabitHeatmapService.weekdayLabel(weekday),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                  for (var slot = 0;
                      slot < habit.ReadingHabitHeatmapService.slotCount;
                      slot++)
                    _buildCell(context, heatmap, weekday, slot),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCell(BuildContext context, habit.ReadingHabitHeatmap heatmap,
      int weekday, int slot) {
    final cell = heatmap.cellAt(weekday, slot);
    final level = heatmap.levelOf(cell);
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Tooltip(
        message:
            '${habit.ReadingHabitHeatmapService.weekdayLabel(weekday)} '
            '${habit.ReadingHabitHeatmapService.slotLabel(slot)} ${cell.minutes}分',
        child: Container(
          key: AppKeys.readingHabitCell(weekday, slot),
          width: 36,
          height: 22,
          decoration: BoxDecoration(
            color: _colorOf(level),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      key: AppKeys.readingHabitLegend,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('少',
            style:
                TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(width: 4),
        for (var level = 0; level <= 4; level++) ...[
          Container(
            width: 14,
            height: 10,
            decoration: BoxDecoration(
              color: _colorOf(level),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 2),
        ],
        const Text('多',
            style:
                TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}