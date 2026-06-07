import 'package:flutter/material.dart';
import 'package:tsundoku_quest/core/theme/app_theme.dart';
import 'package:tsundoku_quest/features/tutorial/presentation/tutorial_content.dart';

/// チュートリアル個別ページWidget
class TutorialPage extends StatelessWidget {
  final TutorialPageData pageData;

  const TutorialPage({super.key, required this.pageData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: pageData.pageKey,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ━━━ アイコン ━━━
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent, width: 2),
            ),
            child: Icon(
              pageData.icon,
              size: 48,
              color: AppTheme.active,
            ),
          ),
          const SizedBox(height: 32),

          // ━━━ タイトル ━━━
          Text(
            pageData.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // ━━━ 本文 ━━━
          Text(
            pageData.body,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
