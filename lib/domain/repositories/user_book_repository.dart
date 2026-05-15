import 'package:tsundoku_quest/domain/models/user_book.dart';

/// ユーザー蔵書リポジトリの抽象インターフェース
abstract class UserBookRepository {
  /// 自分の全蔵書を取得
  Future<List<UserBook>> getMyBooks();

  /// 読書状態で絞り込み
  Future<List<UserBook>> getByStatus(BookStatus status);

  /// IDで蔵書を取得
  Future<UserBook?> getById(String id);

  /// 蔵書を追加
  Future<UserBook> addBook(UserBook userBook);

  /// 蔵書情報を更新
  Future<UserBook> updateBook(UserBook userBook);

  /// 蔵書を削除
  Future<void> deleteBook(String id);
}
