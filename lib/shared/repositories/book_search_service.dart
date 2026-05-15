import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/shared/repositories/rakuten_api.dart';
import 'package:tsundoku_quest/shared/repositories/openbd_api.dart';
import 'package:tsundoku_quest/shared/repositories/google_books_api.dart';

/// 書籍検索の統合サービス
///
/// 楽天 → OpenBD → Google Books の3段フォールバック。
class BookSearchService {
  final RakutenApi _rakuten;
  final OpenBDApi _openbd;
  final GoogleBooksApi _googleBooks;

  BookSearchService({
    required RakutenApi rakuten,
    required OpenBDApi openbd,
    required GoogleBooksApi googleBooks,
  })  : _rakuten = rakuten,
        _openbd = openbd,
        _googleBooks = googleBooks;

  /// キーワード検索
  ///
  /// 1. 楽天ブックス
  /// 2. OpenBD (ISBN判定時のみ)
  /// 3. Google Books
  Future<List<Book>> search(String query) async {
    // 1. 楽天
    final rakutenResults = await _rakuten.search(query);
    if (rakutenResults.isNotEmpty) return rakutenResults;

    final cleaned = _cleanIsbn(query);

    // 2. OpenBD (ISBNのみ)
    if (isIsbn(query)) {
      final openbdResult = await _openbd.lookupByIsbn(cleaned);
      if (openbdResult != null) return [openbdResult];
    }

    // 3. Google Books
    return _googleBooks.search(query);
  }

  /// ISBN ルックアップ
  ///
  /// 楽天(isbnjan) → OpenBD → Google Books(isbn:プレフィックス)
  Future<Book?> lookupByIsbn(String isbn) async {
    final cleaned = _cleanIsbn(isbn);

    // 1. 楽天
    final rakutenResult = await _rakuten.lookupByIsbn(cleaned);
    if (rakutenResult != null) return rakutenResult;

    // 2. OpenBD
    final openbdResult = await _openbd.lookupByIsbn(cleaned);
    if (openbdResult != null) return openbdResult;

    // 3. Google Books
    return _googleBooks.lookupByIsbn(cleaned);
  }

  /// ISBN 判定: ハイフン・空白除去後、10桁または13桁の数字列かどうか
  static bool isIsbn(String s) {
    final cleaned = _cleanIsbn(s);
    if (cleaned.isEmpty) return false;
    return RegExp(r'^\d{10}$').hasMatch(cleaned) ||
        RegExp(r'^\d{13}$').hasMatch(cleaned);
  }

  /// ハイフン・空白を除去
  static String _cleanIsbn(String s) {
    return s.replaceAll(RegExp(r'[\-\s]'), '');
  }
}
