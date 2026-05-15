import 'package:tsundoku_quest/domain/models/book.dart';

/// 書誌リポジトリの抽象インターフェース
abstract class BookRepository {
  /// IDで書誌を取得
  Future<Book?> getById(String id);

  /// ISBNで書誌を取得
  Future<Book?> getByIsbn(String isbn);

  /// キーワードで書誌を検索
  Future<List<Book>> search(String query);

  /// 書誌を新規作成または更新（upsert）
  Future<Book> upsert(Book book);
}
