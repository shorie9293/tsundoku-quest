import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../domain/models/recommendation.dart';

/// 今日のおすすめを表示するカード
///
/// 表紙画像がある場合は上部に表示する。
/// 表紙画像がない場合はテキスト情報のみを表示する。
class RecommendationCard extends StatelessWidget {
  final Recommendation recommendation;

  static const Key recommendationCard = Key('card_recommendation');

  const RecommendationCard({
    super.key,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final title = recommendation.bookTitle;
    final author = recommendation.author;

    return Container(
      key: AppKeys.recommendationCard,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withAlpha(80)),
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
          // Section header
          const Text(
            '🎯 今日のおすすめ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.active,
            ),
          ),
          const SizedBox(height: 12),
          // Cover image — 表紙画像がある場合のみ表示
          if (recommendation.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    recommendation.imageUrl!,
                    height: 120,
                    width: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.broken_image,
                            color: AppTheme.textSecondary),
                      );
                    },
                  ),
                ),
              ),
            ),
          // Book title
          Semantics(
            container: true,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Author
          Semantics(
            container: true,
            child: Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Reason
          Semantics(
            container: true,
            child: Text(
              recommendation.reason,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Read button
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              container: true,
              child: ElevatedButton(
                onPressed: () => context.push('/reading?id=${recommendation.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  '読書を始める',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
