import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tsundoku_quest/domain/models/book.dart';

/// Google Books API
///
/// https://www.googleapis.com/books/v1/volumes?q={query}&key={KEY}&maxResults=10&langRestrict=ja
class GoogleBooksApi {
  final http.Client _client;
  final String _apiKey;

  static const String _endpoint = 'https://www.googleapis.com/books/v1/volumes';

  GoogleBooksApi({
    required String apiKey,
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey;

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
      if (response.statusCode != 200) return [];

      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return [];

      return items
          .map((item) => _parseItem(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
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
      if (response.statusCode != 200) return null;

      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;

      return _parseItem(items.first as Map<String, dynamic>);
    } catch (_) {
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
