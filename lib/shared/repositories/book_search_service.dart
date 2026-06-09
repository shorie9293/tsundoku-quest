import 'package:flutter/foundation.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/shared/repositories/rakuten_api.dart';
import 'package:tsundoku_quest/shared/repositories/openbd_api.dart';
import 'package:tsundoku_quest/shared/repositories/google_books_api.dart';

/// 書籍検索で全APIが失敗した場合の例外
class SearchException implements Exception {
  final String message;
  final List<Object> errors;

  SearchException(this.message, [this.errors = const []]);

  @override
  String toString() => 'SearchException: $message';
}

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
    final errors = <Object>[];

    // 1. 楽天
    try {
      final rakutenResults = await _rakuten.search(query);
      if (rakutenResults.isNotEmpty) return rakutenResults;
    } catch (e) {
      debugPrint('⚠️ 楽天API 検索失敗: $e');
      errors.add(e);
    }

    final cleaned = _cleanIsbn(query);

    // 2. OpenBD (ISBNのみ)
    if (isIsbn(query)) {
      try {
        final openbdResult = await _openbd.lookupByIsbn(cleaned);
        if (openbdResult != null) return [openbdResult];
      } catch (e) {
        debugPrint('⚠️ OpenBD API 検索失敗: $e');
        errors.add(e);
      }
    }

    // 3. Google Books
    try {
      return await _googleBooks.search(query);
    } catch (e) {
      debugPrint('⚠️ Google Books API 検索失敗: $e');
      errors.add(e);
    }

    // 全APIで例外が発生した場合は SearchException を投げる
    // (単に結果が空だった場合は空リストを返す)
    if (_allApisAttempted(query) && errors.isNotEmpty && errors.length >= _apiCount(query)) {
      throw SearchException('すべての検索サービスが利用できません', errors);
    }

    return [];
  }

  /// ISBN ルックアップ
  ///
  /// 楽天(isbnjan) → OpenBD → Google Books(isbn:プレフィックス)
  Future<Book?> lookupByIsbn(String isbn) async {
    final cleaned = _cleanIsbn(isbn);
    final errors = <Object>[];

    // 1. 楽天
    try {
      final rakutenResult = await _rakuten.lookupByIsbn(cleaned);
      if (rakutenResult != null) return rakutenResult;
    } catch (e) {
      debugPrint('⚠️ 楽天API ISBN検索失敗: $e');
      errors.add(e);
    }

    // 2. OpenBD
    try {
      final openbdResult = await _openbd.lookupByIsbn(cleaned);
      if (openbdResult != null) return openbdResult;
    } catch (e) {
      debugPrint('⚠️ OpenBD API ISBN検索失敗: $e');
      errors.add(e);
    }

    // 3. Google Books
    try {
      return await _googleBooks.lookupByIsbn(cleaned);
    } catch (e) {
      debugPrint('⚠️ Google Books API ISBN検索失敗: $e');
      errors.add(e);
    }

    // 全APIで例外が発生した場合
    if (errors.length >= 3) {
      throw SearchException('すべてのISBN検索サービスが利用できません', errors);
    }

    return null;
  }

  /// queryがISBN判定できるかどうかに基づいて試行API数を返す
  int _apiCount(String query) => isIsbn(query) ? 3 : 2;

  /// 全APIが試行されたか
  bool _allApisAttempted(String query) => isIsbn(query) ? true : true; // searchでは常に全APIを試行

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
