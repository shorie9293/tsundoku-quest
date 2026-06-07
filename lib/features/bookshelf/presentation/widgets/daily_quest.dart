import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../data/daily_mission_provider.dart';
import '../../domain/daily_mission.dart';

/// 今日のクエスト表示（デイリーミッション一覧）
class DailyQuest extends ConsumerWidget {
  final bool hasBooks;
  final VoidCallback onStartQuest;

  const DailyQuest({
    super.key,
    required this.hasBooks,
    required this.onStartQuest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionState = ref.watch(dailyMissionProvider);
    final missions = missionState.missions;

    if (missions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withAlpha(100)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x1A7C3AED),
            Color(0x0D1C1917),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text(
                '今日のクエスト',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.active,
                ),
              ),
              const Spacer(),
              Text(
                '${missionState.completedCount}/${missionState.totalCount}',
                style: TextStyle(
                  fontSize: 12,
                  color: missionState.allCompleted
                      ? AppTheme.completedColor
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ミッション一覧
          ...missions.map((mission) => _MissionRow(mission: mission)),

          const SizedBox(height: 12),

          // 冒険開始ボタン
          if (!missionState.allCompleted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStartQuest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  hasBooks ? '冒険をはじめる' : '最初の冒険の書を登録する',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // 全達成時の表示
          if (missionState.allCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.completedColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '🎉 今日のクエストは全て達成！お疲れ様でした！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.completedColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 個別のミッション行
class _MissionRow extends StatelessWidget {
  final DailyMission mission;

  const _MissionRow({required this.mission});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // アイコン
          Text(mission.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),

          // タイトル・説明・プログレスバー
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mission.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: mission.isCompleted
                              ? AppTheme.completedColor
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    // XP報酬バッジ
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: mission.isCompleted
                            ? AppTheme.completedColor.withAlpha(40)
                            : AppTheme.accent.withAlpha(50),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        mission.isCompleted
                            ? '✅'
                            : '+${mission.xpReward} XP',
                        style: TextStyle(
                          fontSize: 10,
                          color: mission.isCompleted
                              ? AppTheme.completedColor
                              : AppTheme.active,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // プログレスバー
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: mission.progress,
                    minHeight: 6,
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      mission.isCompleted
                          ? AppTheme.completedColor
                          : AppTheme.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 2),

                // 進捗テキスト
                Text(
                  mission.isCompleted
                      ? '達成！'
                      : '${mission.currentProgress}/${mission.target} ${_unitLabel(mission.type)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: mission.isCompleted
                        ? AppTheme.completedColor
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _unitLabel(DailyMissionType type) {
    switch (type) {
      case DailyMissionType.readTime:
        return '分';
      case DailyMissionType.readPages:
        return 'ページ';
      case DailyMissionType.completeBook:
        return '冊';
    }
  }
}
