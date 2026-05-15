import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:tsundoku_quest/domain/models/book.dart';

/// OpenBD API (https://api.openbd.jp/v1/get?isbn={isbn})
///
/// 無料・無制限の書誌情報API。
class OpenBDApi {
  final http.Client _client;

  static const String _endpoint = 'https://api.openbd.jp/v1/get';

  OpenBDApi({http.Client? client}) : _client = client ?? http.Client();

  /// ISBN によるルックアップ
  Future<Book?> lookupByIsbn(String isbn) async {
    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {'isbn': isbn},
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;

      final List<dynamic> body =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      if (body.isEmpty) return null;

      final item = body.first;
      if (item == null) return null;

      final data = item as Map<String, dynamic>;
      return _parseItem(data);
    } catch (_) {
      return null;
    }
  }

  Book _parseItem(Map<String, dynamic> data) {
    final isbn = data['isbn'] as String? ?? '';
    return Book(
      id: 'openbd-$isbn-${_randomSuffix()}',
      isbn13: _normalizeIsbn13(isbn),
      title: data['title'] as String? ?? '',
      authors: _parseAuthors(data['author'] as String?),
      publisher: _emptyToNull(data['publisher'] as String?),
      publishedDate: _emptyToNull(data['pubdate'] as String?),
      description: null,
      pageCount: null,
      coverImageUrl: _emptyToNull(data['cover'] as String?),
      source: BookSource.openbd,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// OpenBD の author フィールドはカンマ区切り。
  static List<String> _parseAuthors(String? author) {
    if (author == null || author.trim().isEmpty) return [];
    return author
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String? _normalizeIsbn13(String isbn) {
    if (isbn.isEmpty) return null;
    final digits = isbn.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 13) return digits;
    if (digits.length == 10) return '978$digits';
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
