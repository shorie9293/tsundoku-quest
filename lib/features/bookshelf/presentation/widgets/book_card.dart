import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/testing/widget_keys.dart';
import '../../../../../domain/models/user_book.dart';

/// 本カード — 表紙・タイトル・進捗・XPを表示
class BookCard extends StatelessWidget {
  final UserBook book;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  Color get _statusColor {
    switch (book.status) {
      case BookStatus.tsundoku:
        return AppTheme.tsundokuColor;
      case BookStatus.reading:
        return AppTheme.readingColor;
      case BookStatus.completed:
        return AppTheme.completedColor;
    }
  }

  String get _statusLabel {
    switch (book.status) {
      case BookStatus.tsundoku:
        return '待機中';
      case BookStatus.reading:
        return '戦闘中！';
      case BookStatus.completed:
        return '討伐済み';
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: AppKeys.confirmDialog,
        title: const Text('本を削除しますか？'),
        content: Text(
          '「${book.book?.title ?? '不明な本'}」を書庫から削除します。'
          'この操作は元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('delete_${book.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete?.call(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              // Cover placeholder
              Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Icon(Icons.menu_book,
                      color: AppTheme.textSecondary, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.book?.title ?? '不明な本',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (book.book?.authors.isNotEmpty == true)
                      Text(
                        book.book!.authors.join(', '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    // 戦闘中は読書時間を常に目立つ形で表示
                    if (book.status == BookStatus.reading)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Text('⚔️', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '${book.totalReadingMinutes}分 経過',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.readingColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (book.totalReadingMinutes > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '⏱ 累計 ${book.totalReadingMinutes}分',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    if (book.status == BookStatus.reading)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: book.book?.pageCount != null &&
                                  book.book!.pageCount! > 0
                              ? book.currentPage / book.book!.pageCount!
                              : 0,
                          backgroundColor: AppTheme.border,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_statusColor),
                          minHeight: 4,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(fontSize: 10, color: _statusColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 16, color: AppTheme.textSecondary),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('編集'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('削除', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
