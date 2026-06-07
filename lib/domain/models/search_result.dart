import 'book.dart';

/// 書籍検索の結果を表現する型
///
/// 検索が成功/失敗/空かを区別し、失敗時は原因を保持する。
sealed class SearchResult {
  const SearchResult();

  /// 成功: 1件以上の結果あり
  factory SearchResult.success(List<Book> books) = SearchSuccess;

  /// 結果なし（APIは正常に応答したが該当なし）
  factory SearchResult.empty() = SearchEmpty;

  /// エラー（APIキー未設定・ネットワークエラー・レート制限等）
  factory SearchResult.error(String reason) = SearchError;

  /// 後方互換: `List<Book>` に変換（成功時のみ本体、他は空）
  List<Book> toBooks() => switch (this) {
        SearchSuccess(:final books) => books,
        _ => [],
      };

  /// 後方互換: 結果があるかどうか
  bool get hasResults => this is SearchSuccess;
}

/// 検索成功（1件以上）
class SearchSuccess extends SearchResult {
  final List<Book> books;
  const SearchSuccess(this.books);
}

/// 検索結果なし（API正常、該当なし）
class SearchEmpty extends SearchResult {
  const SearchEmpty();
}

/// 検索エラー
class SearchError extends SearchResult {
  final String reason;
  const SearchError(this.reason);
}
