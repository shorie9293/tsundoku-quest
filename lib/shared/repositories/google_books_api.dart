import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/shared/load_state.dart';

/// Google Books API
///
/// https://www.googleapis.com/books/v1/volumes?q={query}&key={KEY}&maxResults=10&langRestrict=ja
class GoogleBooksApi {
  final http.Client _client;
  final String _apiKey;

  /// true のとき、通信例外・HTTP異常を握り潰さずに例外として投げる。
  ///
  /// 既存の [search] / [lookupByIsbn] は後方互換のため既定で false（空を返す）。
  /// 失敗と0件を分離したい呼び出し側は [GoogleBooksLoadApi.trySearch] を使う。
  /// （テストダブルの `implements GoogleBooksApi` を壊さないよう private 保持）
  final bool _throwOnError;

  static const String _endpoint = 'https://www.googleapis.com/books/v1/volumes';

  GoogleBooksApi({
    required String apiKey,
    http.Client? client,
    bool throwOnError = false,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey,
        _throwOnError = throwOnError;

  /// キーワード検索
  Future<List<Book>> search(String query) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': query,
      'key': _apiKey,
      'maxResults': '10',
      'langRestrict': 'ja',
    });

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        if (_throwOnError) {
          throw GoogleBooksException(
            'Google Books が HTTP ${response.statusCode} を返しました',
            statusCode: response.statusCode,
          );
        }
        return [];
      }

      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return [];

      return items
          .map((item) => _parseItem(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      if (_throwOnError) rethrow;
      return [];
    }
  }

  /// ISBN によるルックアップ (isbn:プレフィックス使用)
  Future<Book?> lookupByIsbn(String isbn) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': 'isbn:$isbn',
      'key': _apiKey,
      'maxResults': '1',
      'langRestrict': 'ja',
    });

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        if (_throwOnError) {
          throw GoogleBooksException(
            'Google Books が HTTP ${response.statusCode} を返しました',
            statusCode: response.statusCode,
          );
        }
        return null;
      }

      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;

      return _parseItem(items.first as Map<String, dynamic>);
    } catch (_) {
      if (_throwOnError) rethrow;
      return null;
    }
  }

  Book _parseItem(Map<String, dynamic> item) {
    final volumeId = item['id'] as String? ?? '';
    final info = item['volumeInfo'] as Map<String, dynamic>? ?? {};

    // ISBN 抽出
    final identifiers = info['industryIdentifiers'] as List<dynamic>?;
    String? isbn13;
    String? isbn10;
    if (identifiers != null) {
      for (final id in identifiers) {
        final m = id as Map<String, dynamic>;
        final type = m['type'] as String?;
        final identifier = m['identifier'] as String?;
        if (type == 'ISBN_13') isbn13 = identifier;
        if (type == 'ISBN_10') isbn10 = identifier;
      }
    }

    // カバー画像: thumbnail → 小さいので、置換して大きいものを試みる
    String? coverUrl;
    final imageLinks = info['imageLinks'] as Map<String, dynamic>?;
    if (imageLinks != null) {
      coverUrl = imageLinks['thumbnail'] as String?;
    }

    return Book(
      id: volumeId,
      isbn13: isbn13,
      isbn10: isbn10,
      title: info['title'] as String? ?? '',
      authors: _parseAuthors(info['authors']),
      publisher: info['publisher'] as String?,
      publishedDate: info['publishedDate'] as String?,
      description: info['description'] as String?,
      pageCount: info['pageCount'] as int?,
      coverImageUrl: coverUrl,
      source: BookSource.googleBooks,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  static List<String> _parseAuthors(dynamic authors) {
    if (authors == null) return [];
    if (authors is List) {
      return authors.map((e) => e.toString()).toList();
    }
    return [];
  }
}

/// Google Books の HTTP/通信異常。
class GoogleBooksException implements Exception {
  final String message;
  final int? statusCode;

  GoogleBooksException(this.message, {this.statusCode});

  @override
  String toString() => 'GoogleBooksException($message)';
}

/// 失敗と0件を分離する読み込み用 API。
///
/// `GoogleBooksApi` の公開インターフェースを増やさないため拡張で提供する
/// （既存のテストダブルが `implements GoogleBooksApi` で書かれているため）。
extension GoogleBooksLoadApi on GoogleBooksApi {
  /// キーワード検索。通信例外・HTTP異常は failure として返す。
  ///
  /// HTTP 200 かつ 0件のときだけ `success(空リスト)`。
  Future<LoadResult<List<Book>>> trySearch(String query) async {
    final uri = Uri.parse(GoogleBooksApi._endpoint).replace(queryParameters: {
      'q': query,
      'key': _apiKey,
      'maxResults': '10',
      'langRestrict': 'ja',
    });

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return LoadResult.failure(
          'Google Books に接続できませんでした（HTTP ${response.statusCode}）',
          cause: GoogleBooksException(
            'HTTP ${response.statusCode}',
            statusCode: response.statusCode,
          ),
        );
      }

      final items = _items(response);
      if (items.isEmpty) return LoadResult.success(const <Book>[]);

      final books = <Book>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) {
          return LoadResult.failure(
            'Google Books の応答を解釈できませんでした',
            cause: FormatException('unexpected item type: ${item.runtimeType}'),
          );
        }
        books.add(_parseItem(item));
      }
      return LoadResult.success(books);
    } catch (e) {
      return LoadResult.failure('Google Books との通信に失敗しました', cause: e);
    }
  }

  /// ISBN 検索。HTTP 200 かつ 0件のときだけ `success(null)`。
  Future<LoadResult<Book?>> trySearchByIsbn(String isbn) async {
    final uri = Uri.parse(GoogleBooksApi._endpoint).replace(queryParameters: {
      'q': 'isbn:$isbn',
      'key': _apiKey,
      'maxResults': '1',
      'langRestrict': 'ja',
    });

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return LoadResult.failure(
          'Google Books に接続できませんでした（HTTP ${response.statusCode}）',
          cause: GoogleBooksException(
            'HTTP ${response.statusCode}',
            statusCode: response.statusCode,
          ),
        );
      }

      final items = _items(response);
      if (items.isEmpty) return LoadResult.success(null);

      final first = items.first;
      if (first is! Map<String, dynamic>) {
        return LoadResult.failure(
          'Google Books の応答を解釈できませんでした',
          cause: FormatException('unexpected item type: ${first.runtimeType}'),
        );
      }
      return LoadResult.success(_parseItem(first));
    } catch (e) {
      return LoadResult.failure('Google Books との通信に失敗しました', cause: e);
    }
  }

  /// items を取り出す。JSON 不正は FormatException として投げる。
  List<dynamic> _items(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('unexpected response body');
    }
    return (decoded['items'] as List<dynamic>?) ?? const <dynamic>[];
  }
}
