import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tsundoku_quest/shared/repositories/rakuten_api.dart';
import 'package:tsundoku_quest/domain/models/book.dart';

/// Fake HTTP client that routes requests based on URL substring matching.
class FakeClient extends http.BaseClient {
  final Map<String, http.Response> _routeMap = {};

  void addResponse(String urlContains, http.Response response) {
    _routeMap[urlContains] = response;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    http.Response? matched;
    for (final entry in _routeMap.entries) {
      if (url.contains(entry.key)) {
        matched = entry.value;
        break;
      }
    }
    final resp =
        matched ?? http.Response(jsonEncode({'error': 'not mocked'}), 404);
    return http.StreamedResponse(
      Stream.fromIterable([resp.bodyBytes]),
      resp.statusCode,
      contentLength: resp.contentLength,
      reasonPhrase: resp.reasonPhrase,
      request: request,
      headers: resp.headers,
    );
  }
}

void main() {
  late FakeClient fakeClient;
  late RakutenApi api;

  setUp(() {
    fakeClient = FakeClient();
    api = RakutenApi(
      appId: 'test-app-id',
      accessKey: 'test-access-key',
      client: fakeClient,
    );
  });

  group('RakutenApi.search', () {
    test('should return list of Books on successful response', () async {
      fakeClient.addResponse(
        'BooksTotal',
        http.Response.bytes(
          utf8.encode(jsonEncode({
            'Items': [
              {
                'Item': {
                  'isbn': '9781234567890',
                  'title': 'テスト駆動開発',
                  'author': 'Kent Beck',
                  'publisherName': 'オーム社',
                  'salesDate': '2025-03',
                  'itemCaption': 'TDDの入門書',
                  'size': '320',
                  'largeImageUrl': 'https://example.com/cover.jpg',
                  'mediumImageUrl': 'https://example.com/thumb.jpg',
                }
              }
            ],
            'count': 1,
          })),
          200,
        ),
      );

      final books = await api.search('テスト駆動開発');

      expect(books.length, 1);
      final book = books.first;
      expect(book.title, 'テスト駆動開発');
      expect(book.isbn13, '9781234567890');
      expect(book.authors, ['Kent Beck']);
      expect(book.publisher, 'オーム社');
      expect(book.publishedDate, '2025-03');
      expect(book.description, 'TDDの入門書');
      expect(book.pageCount, 320);
      expect(book.coverImageUrl, 'https://example.com/thumb.jpg');
      expect(book.source, BookSource.rakuten);
    });

    test('should return empty list when response has no Items', () async {
      fakeClient.addResponse(
        'BooksTotal',
        http.Response(
          jsonEncode({'count': 0}),
          200,
        ),
      );

      final books = await api.search('存在しない本');

      expect(books, isEmpty);
    });

    test('should return empty list on API error response', () async {
      fakeClient.addResponse(
        'BooksTotal',
        http.Response(
          jsonEncode({
            'error': 'invalid_request',
            'error_description': 'Invalid application ID',
          }),
          400,
        ),
      );

      final books = await api.search('何でも');

      expect(books, isEmpty);
    });

    test('should return empty list when Items is empty array', () async {
      fakeClient.addResponse(
        'BooksTotal',
        http.Response(
          jsonEncode({'Items': <dynamic>[], 'count': 0}),
          200,
        ),
      );

      final books = await api.search('ヒットなし');

      expect(books, isEmpty);
    });

    test('should use keyword parameter for search', () async {
      late String requestUrl;
      // Wrap the client to capture the URL
      final capturingClient = _CapturingClient(
        onSend: (req) async {
          requestUrl = req.url.toString();
          return http.StreamedResponse(
            Stream.fromIterable([
              utf8.encode(jsonEncode({'Items': <dynamic>[], 'count': 0}))
            ]),
            200,
            request: req,
          );
        },
      );
      final capturingApi = RakutenApi(
        appId: 'app',
        accessKey: 'key',
        client: capturingClient,
      );

      await capturingApi.search('Flutter');

      expect(requestUrl, contains('keyword=Flutter'));
      expect(requestUrl, contains('applicationId=app'));
      expect(requestUrl, contains('accessKey=key'));
      expect(requestUrl, contains('format=json'));
      expect(requestUrl, contains('hits=10'));
    });
  });

  group('RakutenApi.lookupByIsbn', () {
    test('should return Book when found via isbnjan', () async {
      fakeClient.addResponse(
        'BooksTotal',
        http.Response.bytes(
          utf8.encode(jsonEncode({
            'Items': [
              {
                'Item': {
                  'isbn': '9784000000000',
                  'title': 'ISBN本',
                  'author': '著者',
                  'publisherName': '出版社',
                  'salesDate': '2024-01',
                  'itemCaption': '',
                  'largeImageUrl': 'https://example.com/large.jpg',
                  'mediumImageUrl': 'https://example.com/medium.jpg',
                }
              }
            ],
            'count': 1,
          })),
          200,
        ),
      );

      final book = await api.lookupByIsbn('9784000000000');

      expect(book, isNotNull);
      expect(book!.title, 'ISBN本');
      expect(book.isbn13, '9784000000000');
      expect(book.source, BookSource.rakuten);
    });

    test('should return null when not found', () async {
      fakeClient.addResponse(
        'BooksTotal',
        http.Response(
          jsonEncode({'Items': <dynamic>[], 'count': 0}),
          200,
        ),
      );

      final book = await api.lookupByIsbn('0000000000000');

      expect(book, isNull);
    });

    test('should use isbnjan parameter', () async {
      late String requestUrl;
      final capturingClient = _CapturingClient(
        onSend: (req) async {
          requestUrl = req.url.toString();
          return http.StreamedResponse(
            Stream.fromIterable([
              utf8.encode(jsonEncode({'Items': <dynamic>[], 'count': 0}))
            ]),
            200,
            request: req,
          );
        },
      );
      final capturingApi = RakutenApi(
        appId: 'app',
        accessKey: 'key',
        client: capturingClient,
      );

      await capturingApi.lookupByIsbn('1234567890123');

      expect(requestUrl, contains('isbnjan=1234567890123'));
    });
  });
}

/// A capturing client that invokes a callback on each request.
class _CapturingClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) onSend;

  _CapturingClient({required this.onSend});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return onSend(request);
  }
}
