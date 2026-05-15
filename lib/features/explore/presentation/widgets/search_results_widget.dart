import 'package:flutter/material.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 検索結果をカードUIで表示するWidget
class SearchResultsWidget extends StatelessWidget {
  final List<Book> books;
  final ValueChanged<Book> onAddBook;

  const SearchResultsWidget({
    super.key,
    required this.books,
    required this.onAddBook,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: AppKeys.searchResultsList,
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return SemanticHelper.listItem(
          testId: SemanticHelper.createTestId('item', 'search_result_$index'),
          index: index,
          child: _BookCard(
            book: book,
            onAdd: () => onAddBook(book),
          ),
        );
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onAdd;

  const _BookCard({required this.book, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('book_card_${book.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 表紙画像
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: book.coverImageUrl != null
                  ? Image.network(
                      book.coverImageUrl!,
                      width: 60,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _PlaceholderCover(),
                    )
                  : const _PlaceholderCover(),
            ),
            const SizedBox(width: 12),
            // 書誌情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (book.authors.isNotEmpty)
                    Text(
                      book.authors.join(', '),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (book.publisher != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      book.publisher!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(180),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 追加ボタン
            SemanticHelper.interactive(
              testId: SemanticHelper.createTestId('btn', 'add_book_${book.id}'),
              label: '蔵書に追加',
              child: IconButton(
                key: AppKeys.searchResultItem,
                icon: const Icon(Icons.add_circle_outline),
                color: theme.colorScheme.primary,
                tooltip: '蔵書に追加',
                onPressed: onAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 90,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.book, size: 32),
    );
  }
}
