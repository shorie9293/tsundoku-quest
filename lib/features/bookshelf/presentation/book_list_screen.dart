import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/testing/widget_keys.dart';
import '../../../../domain/models/user_book.dart';
import 'widgets/book_card.dart';
import 'widgets/edit_book_modal.dart';

/// フィルタリングされた本一覧画面
/// 足跡画面の統計カードタップで遷移する
class BookListScreen extends StatelessWidget {
  final String title;
  final List<UserBook> books;

  const BookListScreen({
    super.key,
    required this.title,
    required this.books,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.bookListScreen,
      appBar: AppBar(title: Text('📋 $title')),
      body: books.isEmpty
          ? const Center(
              child: Text(
                '表示する本がありません',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : ListView.builder(
              key: AppKeys.bookListListView,
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return BookCard(
                  book: book,
                  onTap: () => Navigator.of(context).pop(),
                  onEdit: () => EditBookModal.show(context, book),
                  onDelete: null,
                );
              },
            ),
    );
  }
}
