import 'package:flutter/material.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/recommendation.dart';

/// 「みんなが読んでいる」セクション
///
/// Supabaseから人気書籍を取得して表示する。
/// オフライン時やエラー時は空状態メッセージを表示する。
///
/// 使用方法:
/// ```dart
/// SocialReadingSection(
///   popularBooks: [],  // 外部から取得済みの人気書籍リスト
/// )
/// ```
class SocialReadingSection extends StatelessWidget {
  /// 表示する人気書籍のリスト（外部から注入）
  final List<Recommendation> popularBooks;

  /// ローディング中かどうか
  final bool isLoading;

  /// エラー発生時に表示するメッセージ（nullの場合はデフォルトメッセージ）
  final String? errorMessage;

  const SocialReadingSection({
    super.key,
    this.popularBooks = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: AppKeys.socialReadingSection,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👥 みんなが読んでいる',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (errorMessage != null || popularBooks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                errorMessage ?? 'オフラインのため表示できません',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            )
          else
            ...(popularBooks.take(3).map(
                  (rec) => _buildBookItem(rec),
                )),
        ],
      ),
    );
  }

  Widget _buildBookItem(Recommendation rec) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (rec.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                rec.imageUrl!,
                height: 48,
                width: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 48,
                    width: 32,
                    color: AppTheme.border,
                  );
                },
              ),
            )
          else
            Container(
              height: 48,
              width: 32,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.book, size: 20, color: AppTheme.textSecondary),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.bookTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rec.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
