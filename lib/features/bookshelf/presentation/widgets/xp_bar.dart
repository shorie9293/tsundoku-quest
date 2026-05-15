import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/testing/widget_keys.dart';

/// XPバー — 冒険者のレベル・称号・XP進捗を表示
class XpBar extends StatelessWidget {
  final int level;
  final int xp;
  final int xpToNextLevel;
  final String title;

  const XpBar({
    super.key,
    required this.level,
    required this.xp,
    required this.xpToNextLevel,
    required this.title,
  });

  double get _progress => xpToNextLevel > 0 ? xp / xpToNextLevel : 0.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: AppKeys.xpBar,
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
              Text(
                'Lv.$level',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.active,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppTheme.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.progress),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$xp / $xpToNextLevel XP',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
