import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

/// 今日のクエスト表示
class DailyQuest extends StatelessWidget {
  final bool hasBooks;
  final VoidCallback onStartQuest;

  const DailyQuest({
    super.key,
    required this.hasBooks,
    required this.onStartQuest,
  });

  @override
  Widget build(BuildContext context) {
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '+50 XP',
                  style: TextStyle(fontSize: 10, color: AppTheme.active),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '📖 15分間の読書をしよう',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'どの本でもOK。1ページでも冒険は始まる！',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
