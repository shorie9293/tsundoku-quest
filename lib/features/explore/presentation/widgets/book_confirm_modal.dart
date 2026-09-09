import 'package:flutter/material.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' as ui;
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';

/// バーコードスキャン後に「本当に登録するか」を確認するモーダル。
///
/// 書誌情報（表紙・タイトル・著者・ページ数）を表示し、
/// ユーザーの意図確認を経てから蔵書登録へ進む二段階導線。
class BookConfirmModal {
  BookConfirmModal._();

  static Future<void> show(
    BuildContext context, {
    required Book book,
    required ValueChanged<Book> onConfirm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => KeyedSubtree(
        key: AppKeys.bookConfirmModal,
        child: _BookConfirmSheet(book: book, onConfirm: onConfirm),
      ),
    );
  }
}

class _BookConfirmSheet extends StatelessWidget {
  final Book book;
  final ValueChanged<Book> onConfirm;

  const _BookConfirmSheet({required this.book, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'この本を登録しますか？',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: book.coverImageUrl != null
                      ? Image.network(
                          book.coverImageUrl!,
                          width: 84,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _CoverPlaceholder(),
                        )
                      : const _CoverPlaceholder(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (book.authors.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          book.authors.join('、'),
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (book.pageCount != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${book.pageCount}ページ',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: AppKeys.bookConfirmCancel,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('やめる'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ui.SemanticHelper.interactive(
                    testId: 'btn_book_confirm_submit',
                    label: 'この本を蔵書に登録する',
                    child: FilledButton(
                      key: AppKeys.bookConfirmSubmit,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onConfirm(book);
                      },
                      child: const Text('登録する'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 120,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.menu_book, size: 36),
    );
  }
}
