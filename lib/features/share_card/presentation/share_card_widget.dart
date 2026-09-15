/// 読了シェアカード表示ウィジェット
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/share_card/domain/share_card_data.dart';

/// 読了書籍の装飾カード（外部アセット・画像不使用）
class ShareCard extends StatelessWidget {
  final ShareCardData data;

  const ShareCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📖 読了達成', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text(
            data.title,
            key: AppKeys.shareCardTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.authorLabel,
            key: AppKeys.shareCardAuthor,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            '読了日: ${data.dateLabel}',
            key: AppKeys.shareCardDate,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            data.pagesLabel,
            key: AppKeys.shareCardPages,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          ),
          if (data.hasRating) ...[
            const SizedBox(height: 4),
            Text(
              '評価: ${'★' * data.rating!}${'☆' * (5 - data.rating!)}',
              key: AppKeys.shareCardRating,
              style: const TextStyle(fontSize: 14, color: AppTheme.active),
            ),
          ],
          if (data.shelves.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              key: AppKeys.shareCardShelves,
              spacing: 6,
              children: [
                for (final shelf in data.shelves)
                  Chip(
                    label: Text(shelf, style: const TextStyle(fontSize: 11)),
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
