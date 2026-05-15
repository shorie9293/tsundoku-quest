import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:tsundoku_quest/domain/models/book.dart';

/// 楽天ブックス書籍検索API
///
/// 2026年新方式: openapi.rakuten.co.jp + applicationId + accessKey 認証
class RakutenApi {
  final http.Client _client;
  final String _appId;
  final String _accessKey;

  static const String _endpoint =
      'https://openapi.rakuten.co.jp/services/api/BooksTotal/Search/20170404';

  RakutenApi({
    required String appId,
    required String accessKey,
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _appId = appId,
        _accessKey = accessKey;

  /// キーワード検索
  Future<List<Book>> search(String query) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'format': 'json',
      'applicationId': _appId,
      'accessKey': _accessKey,
      'keyword': query,
      'hits': '10',
    });

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return [];

      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (body.containsKey('error')) return [];

      final items = body['Items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return [];

      return items.map((item) {
        final i = item['Item'] as Map<String, dynamic>;
        return _parseItem(i);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// ISBN によるルックアップ (isbnjanパラメータ使用)
  Future<Book?> lookupByIsbn(String isbn) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'format': 'json',
      'applicationId': _appId,
      'accessKey': _accessKey,
      'isbnjan': isbn,
      'hits': '1',
    });

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;

      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (body.containsKey('error')) return null;

      final items = body['Items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;

      final i = items.first['Item'] as Map<String, dynamic>;
      return _parseItem(i);
    } catch (_) {
      return null;
    }
  }

  Book _parseItem(Map<String, dynamic> i) {
    final isbn = i['isbn'] as String? ?? '';
    return Book(
      id: 'rakuten-$isbn-${_randomSuffix()}',
      isbn13: _normalizeIsbn13(isbn),
      title: i['title'] as String? ?? '',
      authors: _parseAuthors(i['author'] as String?),
      publisher: _emptyToNull(i['publisherName'] as String?),
      publishedDate: _emptyToNull(i['salesDate'] as String?),
      description: _emptyToNull(i['itemCaption'] as String?),
      pageCount: int.tryParse(i['size'] as String? ?? ''),
      coverImageUrl: _emptyToNull(i['mediumImageUrl'] as String?) ??
          _emptyToNull(i['largeImageUrl'] as String?),
      source: BookSource.rakuten,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  static List<String> _parseAuthors(String? author) {
    if (author == null || author.trim().isEmpty) return [];
    return author
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String? _normalizeIsbn13(String isbn) {
    if (isbn.isEmpty) return null;
    // 楽天は10桁または13桁を返す。13桁に正規化する簡易ロジック
    final digits = isbn.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 13) return digits;
    if (digits.length == 10) return '978$digits'; // 簡易変換
    return digits.isEmpty ? null : digits;
  }

  static String? _emptyToNull(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return s.trim();
  }

  static String _randomSuffix() {
    final rng = Random();
    return rng.nextInt(999999).toString().padLeft(6, '0');
  }
}
