import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsundoku_quest/core/theme/app_theme.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/goals/data/reading_goal_provider.dart';
import 'package:tsundoku_quest/features/goals/domain/reading_goal.dart';

/// 読書目標の進捗カード（足跡画面に埋め込む）
class ReadingGoalCard extends ConsumerWidget {
  const ReadingGoalCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(readingGoalControllerProvider);
    final monthly = ref.watch(monthlyGoalProgressProvider);
    final yearly = ref.watch(yearlyGoalProgressProvider);

    return Container(
      key: AppKeys.readingGoalCard,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎯',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('読書目標',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReadingGoalScreen(initialGoal: goal),
                  ),
                ),
                child: Text(goal.isConfigured ? '設定を変更' : '目標を立てる'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!goal.isConfigured)
            const Text(
              '月間・年間の読了目標を設定して、達成度を追いかけよう',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            )
          else ...[
            if (monthly.isSet) _GoalRow(label: '今月', progress: monthly),
            if (monthly.isSet && yearly.isSet) const SizedBox(height: 12),
            if (yearly.isSet) _GoalRow(label: '今年', progress: yearly),
          ],
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.label, required this.progress});

  final String label;
  final ReadingGoalProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$label ',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            Expanded(
              child: Text(
                '${progress.achieved} / ${progress.target} 冊',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary),
              ),
            ),
            Text('${progress.badge.icon} ${progress.badge.label}',
                style: const TextStyle(fontSize: 12, color: AppTheme.active)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.ratio,
            minHeight: 6,
            backgroundColor: AppTheme.border,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.progress),
          ),
        ),
      ],
    );
  }
}

/// 読書目標の設定と達成トラッキング画面
class ReadingGoalScreen extends ConsumerStatefulWidget {
  const ReadingGoalScreen({super.key, this.initialGoal});

  /// 初期値（カードからの遷移時に引き継ぐ。null なら Provider から読む）
  final ReadingGoal? initialGoal;

  @override
  ConsumerState<ReadingGoalScreen> createState() => _ReadingGoalScreenState();
}

class _ReadingGoalScreenState extends ConsumerState<ReadingGoalScreen> {
  late final TextEditingController _monthlyController;
  late final TextEditingController _yearlyController;

  @override
  void initState() {
    super.initState();
    final ReadingGoal goal = widget.initialGoal ??
        ref.read(readingGoalControllerProvider);
    _monthlyController = TextEditingController(
      text: goal.isMonthlySet ? '${goal.monthlyTarget}' : '',
    );
    _yearlyController = TextEditingController(
      text: goal.isYearlySet ? '${goal.yearlyTarget}' : '',
    );
  }

  @override
  void dispose() {
    _monthlyController.dispose();
    _yearlyController.dispose();
    super.dispose();
  }

  int _parseTarget(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim()) ?? 0;
    return value > 0 ? value : 0;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(readingGoalControllerProvider.notifier).saveTargets(
          monthlyTarget: _parseTarget(_monthlyController),
          yearlyTarget: _parseTarget(_yearlyController),
        );
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('✅ 読書目標を保存しました')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    await ref.read(readingGoalControllerProvider.notifier).clear();
    if (!mounted) return;
    _monthlyController.clear();
    _yearlyController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final monthly = ref.watch(monthlyGoalProgressProvider);
    final yearly = ref.watch(yearlyGoalProgressProvider);

    return Scaffold(
      key: AppKeys.readingGoalScreen,
      appBar: AppBar(title: const Text('🎯 読書目標')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProgressPanel(title: '今月の進捗', progress: monthly),
          const SizedBox(height: 12),
          _ProgressPanel(title: '今年の進捗', progress: yearly),
          const SizedBox(height: 24),
          const Text('目標を設定する',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          TextField(
            key: AppKeys.readingGoalMonthlyField,
            controller: _monthlyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '月間の読了目標（冊）',
              hintText: '例: 2',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: AppKeys.readingGoalYearlyField,
            controller: _yearlyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '年間の読了目標（冊）',
              hintText: '例: 24',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: AppKeys.readingGoalSaveButton,
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                key: AppKeys.readingGoalClearButton,
                onPressed: _clear,
                child: const Text('解除'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '💡 空欄で保存すると「未設定」になります。達成度に応じて '
            '🧭 挑戦開始 → ⚔️ 折り返し → 🔥 あと少し → 🏆 目標達成 とバッジが進みます。',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.title, required this.progress});

  final String title;
  final ReadingGoalProgress progress;

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
                  fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Text(
            progress.isSet
                ? '${progress.achieved} / ${progress.target} 冊（${progress.percent}%）'
                : '未設定',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.ratio,
              minHeight: 8,
              backgroundColor: AppTheme.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.progress),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress.isSet
                ? '${progress.badge.icon} ${progress.badge.label}'
                    '${progress.isAchieved ? '' : ' ・ 残り${progress.remaining}冊'}'
                : '🎯 未設定',
            style: const TextStyle(fontSize: 12, color: AppTheme.active),
          ),
        ],
      ),
    );
  }
}
