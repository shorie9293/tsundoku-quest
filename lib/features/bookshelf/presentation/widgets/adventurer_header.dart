import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/testing/widget_keys.dart';
import '../../../../../shared/providers/adventurer_provider.dart';
import 'xp_bar.dart';

/// 冒険者ヘッダー — 挨拶＋XPバー＋統計チップ（adventurerProvider を内部監視）
class AdventurerHeader extends ConsumerWidget {
  const AdventurerHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adventurer = ref.watch(adventurerProvider);
    final level = adventurer.level;
    final xp = adventurer.xp;
    final xpToNextLevel = adventurer.xpToNextLevel;
    final title = adventurer.title;
    return Column(
      key: AppKeys.adventurerHeader,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '⚔️',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '冒険者',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        XpBar(
          level: level,
          xp: xp,
          xpToNextLevel: xpToNextLevel,
          title: title,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatChip(icon: '⏱', label: '読書時間', value: '${adventurer.totalReadingMinutes}分'),
            _StatChip(icon: '📄', label: '累計ページ', value: '${adventurer.totalPagesRead}P'),
            _StatChip(icon: '📚', label: '登録数', value: '${adventurer.totalBooksRegistered}冊'),
            _StatChip(icon: '🏆', label: '読了', value: '${adventurer.totalBooksCompleted}冊'),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}
