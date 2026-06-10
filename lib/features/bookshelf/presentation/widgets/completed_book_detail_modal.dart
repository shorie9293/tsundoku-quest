import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../domain/models/user_book.dart';
import '../../../../../domain/models/war_trophy.dart';
import '../../../shared/providers/war_trophy_provider.dart';

/// 読了本の詳細モーダル — 戦利品カード・読了日・読書時間・星評価を表示
class CompletedBookDetailModal extends StatelessWidget {
  final UserBook book;

  const CompletedBookDetailModal({super.key, required this.book});

  /// モーダルを表示する
  static Future<void> show(BuildContext context, UserBook book) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CompletedBookDetailContent(book: book),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Not used directly — use show() instead
    return const SizedBox.shrink();
  }
}

class _CompletedBookDetailContent extends ConsumerWidget {
  final UserBook book;

  const _CompletedBookDetailContent({required this.book});

  String _formatDate(String iso8601) {
    try {
      final dt = DateTime.parse(iso8601);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso8601;
    }
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) {
      return '$h時間${m > 0 ? ' $m分' : ''}';
    }
    return '$m分';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trophies = ref.watch(warTrophyProvider);
    final trophy = trophies.where((t) => t.userBookId == book.id).firstOrNull;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // タイトル
              Text(
                book.book?.title ?? '不明な本',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (book.book?.authors.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  book.book!.authors.join(', '),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 読了情報カード
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 読了情報',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _infoRow('⭐ 評価', _buildStars(book.rating)),
                    const SizedBox(height: 8),
                    _infoRow('📅 読了日',
                        book.completedAt != null ? _formatDate(book.completedAt!) : '---'),
                    const SizedBox(height: 8),
                    _infoRow(
                        '⏱ 読書時間', _formatMinutes(book.totalReadingMinutes)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 戦利品カード
              if (trophy != null) ...[
                const Text(
                  '⚔️ 戦利品',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.badge,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTrophyCard(trophy),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Center(
                    child: Text(
                      '戦利品カードはまだ作成されていません',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _buildStars(int? rating) {
    if (rating == null) return '---';
    return '⭐' * rating + (rating < 5 ? '☆' * (5 - rating) : '');
  }

  Widget _buildTrophyCard(WarTrophy trophy) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.badge.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 学び
          const Text(
            '📖 学んだこと',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...trophy.learnings.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key + 1}. ',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),

          // 行動
          const Text(
            '⚡ 行動に移すこと',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trophy.action,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),

          // お気に入りの一文
          if (trophy.favoriteQuote != null &&
              trophy.favoriteQuote!.isNotEmpty) ...[
            const Text(
              '💬 お気に入りの一文',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                trophy.favoriteQuote!,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
