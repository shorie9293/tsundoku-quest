import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/goals/data/daily_reading_goal_provider.dart';
import 'package:tsundoku_quest/features/goals/domain/daily_reading_goal_service.dart';
import 'package:tsundoku_quest/features/history/data/reading_habit_provider.dart';

/// 1日の読書時間目標の設定と達成トラッキング画面
///
/// 現代（tsundoku-quest）改善提案#119。
/// 目標分数と日別達成・ストリークを表示する。純粋ロジックは
/// [DailyReadingGoalService] に委譲し、本画面は表示と入力のみを担う。
class DailyReadingGoalScreen extends ConsumerStatefulWidget {
  const DailyReadingGoalScreen({
    super.key,
    this.sessionsOverride,
    this.nowOverride,
  });

  /// 試練用のセッション注入（null なら provider から取得）
  final List<ReadingSession>? sessionsOverride;

  /// 試練用の現在時刻注入
  final DateTime? nowOverride;

  @override
  ConsumerState<DailyReadingGoalScreen> createState() =>
      _DailyReadingGoalScreenState();
}

class _DailyReadingGoalScreenState
    extends ConsumerState<DailyReadingGoalScreen> {
  final TextEditingController _targetController = TextEditingController();

  static const List<int> _presets = [15, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    // 保存済み目標を読み込み、入力欄へ初期値を反映する
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(dailyReadingGoalControllerProvider.notifier).load();
      if (!mounted) return;
      final current = ref.read(dailyReadingGoalControllerProvider);
      if (current.isSet) {
        _targetController.text = '${current.targetMinutes}';
      }
    });
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  // widget の最新値に追随させる（late final で捕捉すると陳腐化する）
  List<ReadingSession> get _sessions =>
      widget.sessionsOverride ??
      ref.watch(readingHabitSessionsProvider).valueOrNull ??
      const <ReadingSession>[];

  DateTime get _now => widget.nowOverride ?? DateTime.now();

  Future<void> _saveFromField() async {
    final raw = _targetController.text.trim();
    final value = int.tryParse(raw);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分数を数値で入力してください')),
      );
      return;
    }
    final notifier = ref.read(dailyReadingGoalControllerProvider.notifier);
    if (value <= 0) {
      await notifier.clear();
    } else {
      await notifier.saveTarget(targetMinutes: value);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value <= 0 ? '目標を解除しました' : '目標を $value 分に設定しました')),
    );
  }

  Future<void> _applyPreset(int minutes) async {
    _targetController.text = '$minutes';
    await ref
        .read(dailyReadingGoalControllerProvider.notifier)
        .saveTarget(targetMinutes: minutes);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('目標を $minutes 分に設定しました')),
    );
  }

  Future<void> _clear() async {
    _targetController.clear();
    await ref.read(dailyReadingGoalControllerProvider.notifier).clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('目標を解除しました')),
    );
  }

  String get _todayLabel {
    final progress = _progress;
    if (!progress.isSet) return '目標未設定';
    return '今日 ${progress.todayMinutes} / ${progress.target}分';
  }

  DailyGoalProgress get _progress {
    final goal = ref.watch(dailyReadingGoalControllerProvider);
    return DailyReadingGoalService.build(
      sessions: _sessions,
      goal: goal,
      now: _now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _progress;
    final goalSet = progress.isSet;

    return Scaffold(
      key: AppKeys.dailyReadingGoalScreen,
      appBar: AppBar(title: const Text('🎯 読書時間の目標')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 今日のカード ──
          SemanticHelper.container(
            testId: 'card_daily_goal_today',
            label: '今日の読書時間',
            explicitChildNodes: true,
            child: Card(
            key: AppKeys.dailyReadingGoalTodayCard,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今日の読書時間', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    _todayLabel,
                    key: AppKeys.dailyReadingGoalTodayLabel,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  SemanticHelper.container(
                    testId: 'progress_daily_goal_today',
                    label: '今日の目標進捗',
                    child: LinearProgressIndicator(
                      value: progress.todayRatio,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (progress.todayAchieved)
                    const Text('🏆 達成！', style: TextStyle(color: Colors.green))
                  else if (goalSet)
                    Text('あと ${progress.target - progress.todayMinutes} 分')
                  else
                    Text(
                      '1日の目標を設定しましょう',
                      key: AppKeys.dailyReadingGoalEmpty,
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ),
          ),
          const SizedBox(height: 16),

          // ── ストリーク ──
          SemanticHelper.container(
            testId: 'card_daily_goal_streak',
            label: '連続達成日数',
            explicitChildNodes: true,
            child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text('🔥 現在'),
                      Text(
                        '現在 ${progress.currentStreak}日',
                        key: AppKeys.dailyReadingGoalStreakCurrent,
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('🏅 最長'),
                      Text(
                        '最長 ${progress.longestStreak}日',
                        key: AppKeys.dailyReadingGoalStreakLongest,
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ),
          const SizedBox(height: 16),

          // ── 直近7日 ──
          Text('直近7日', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SemanticHelper.container(
            testId: 'chart_daily_goal_seven_days',
            label: '直近7日の読書時間',
            explicitChildNodes: true,
            child: Row(
              key: AppKeys.dailyReadingGoalSevenDayRow,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final day in progress.lastSevenDays)
                  _DayBar(day: day, maxMinutes: _maxPositive(progress)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 目標設定 ──
          Text('目標を設定', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            key: AppKeys.dailyReadingGoalPresetChips,
            spacing: 8,
            children: [
              for (final minutes in _presets)
                SemanticHelper.interactive(
                  testId: 'btn_daily_goal_preset_$minutes',
                  label: '$minutes分の目標を設定',
                  child: ActionChip(
                    key: AppKeys.dailyReadingGoalChip(minutes),
                    label: Text('$minutes分'),
                    onPressed: () => _applyPreset(minutes),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SemanticHelper.textField(
                  testId: 'txt_daily_goal_target',
                  label: '1日の目標（分）',
                  child: TextField(
                    key: AppKeys.dailyReadingGoalTargetField,
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '1日の目標（分）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SemanticHelper.interactive(
                  testId: 'btn_daily_goal_save',
                  label: '目標を保存',
                  child: FilledButton(
                    key: AppKeys.dailyReadingGoalSaveButton,
                    onPressed: _saveFromField,
                    child: const Text('保存'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SemanticHelper.interactive(
                  testId: 'btn_daily_goal_clear',
                  label: '目標を解除',
                  child: OutlinedButton(
                    key: AppKeys.dailyReadingGoalClearButton,
                    onPressed: _clear,
                    child: const Text('解除'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _maxPositive(DailyGoalProgress progress) {
    var max = 0;
    for (final day in progress.lastSevenDays) {
      if (day.minutes > max) max = day.minutes;
    }
    if (progress.target > max) max = progress.target;
    return max;
  }
}

/// 1日分のバー
class _DayBar extends StatelessWidget {
  const _DayBar({required this.day, required this.maxMinutes});

  final DailyGoalDay day;
  final int maxMinutes;

  @override
  Widget build(BuildContext context) {
    const barMaxHeight = 80.0;
    final ratio = maxMinutes <= 0 ? 0.0 : (day.minutes / maxMinutes);
    final height = (barMaxHeight * ratio).clamp(4.0, barMaxHeight);
    final color = day.isAchieved
        ? Colors.green
        : Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${day.minutes}', style: const TextStyle(fontSize: 10)),
        const SizedBox(height: 2),
        Container(
          width: 18,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 2),
        Text(day.date.substring(5), style: const TextStyle(fontSize: 9)),
      ],
    );
  }
}
