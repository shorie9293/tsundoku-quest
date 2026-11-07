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

  /// 一括選択モードで選択されているか（既定 false＝通常表示）。
  final bool selected;

  /// 一括選択モード中か。true の間はスワイプ削除を無効化し、
  /// 選択チェックアイコンを表示する。
  final bool selectionMode;

  /// 長押し時のコールバック（一括選択モードへの入口）。
  final VoidCallback? onLongPress;

  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
    this.selected = false,
    this.selectionMode = false,
    this.onLongPress,
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

  /// ISO8601文字列を yyyy/MM/dd に変換
  String _formatCompletedDate(String iso8601) {
    try {
      final dt = DateTime.parse(iso8601);
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso8601;
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
      direction:
          selectionMode ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: selectionMode ? null : (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete?.call(),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.accent : AppTheme.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    key: AppKeys.bookCardCheckbox(book.id),
                    size: 20,
                    color: selected ? AppTheme.accent : AppTheme.textSecondary,
                  ),
                ),
              // Cover image or placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: book.book?.coverImageUrl != null
                    ? Image.network(
                        book.book!.coverImageUrl!,
                        width: 48,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
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
                      )
                    : Container(
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
                    // 読了本：星評価と読了日を表示
                    if (book.status == BookStatus.completed)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            if (book.rating != null) ...[
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  i < book.rating!
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 12,
                                  color: AppTheme.badge,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (book.completedAt != null)
                              Text(
                                _formatCompletedDate(book.completedAt!),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
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
