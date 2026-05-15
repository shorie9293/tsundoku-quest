import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tsundoku_quest/shared/repositories/google_books_api.dart';
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
  late GoogleBooksApi api;

  setUp(() {
    fakeClient = FakeClient();
    api = GoogleBooksApi(apiKey: 'test-key', client: fakeClient);
  });

  group('GoogleBooksApi.search', () {
    test('should return list of Books on successful response', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'vol123',
                'volumeInfo': {
                  'title': 'Test Driven Development',
                  'authors': ['Kent Beck'],
                  'publisher': 'Addison-Wesley',
                  'publishedDate': '2025-05',
                  'description': 'A book about TDD',
                  'pageCount': 250,
                  'imageLinks': {
                    'thumbnail': 'https://books.google.com/thumbnail.jpg',
                  },
                  'industryIdentifiers': [
                    {'type': 'ISBN_13', 'identifier': '9781111111111'},
                    {'type': 'ISBN_10', 'identifier': '1111111111'},
                  ],
                }
              }
            ]
          }),
          200,
        ),
      );

      final books = await api.search('TDD');

      expect(books.length, 1);
      final book = books.first;
      expect(book.title, 'Test Driven Development');
      expect(book.isbn13, '9781111111111');
      expect(book.isbn10, '1111111111');
      expect(book.authors, ['Kent Beck']);
      expect(book.publisher, 'Addison-Wesley');
      expect(book.publishedDate, '2025-05');
      expect(book.description, 'A book about TDD');
      expect(book.pageCount, 250);
      expect(book.coverImageUrl, 'https://books.google.com/thumbnail.jpg');
      expect(book.source, BookSource.googleBooks);
      expect(book.id, 'vol123');
    });

    test('should return empty list when no items in response', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response(jsonEncode({}), 200),
      );

      final books = await api.search('nothing');

      expect(books, isEmpty);
    });

    test('should return empty list on API error', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response('error', 403),
      );

      final books = await api.search('anything');

      expect(books, isEmpty);
    });

    test('should handle missing imageLinks', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'vol456',
                'volumeInfo': {
                  'title': 'No Cover Book',
                  'authors': ['Anonymous'],
                }
              }
            ]
          }),
          200,
        ),
      );

      final books = await api.search('no cover');

      expect(books.length, 1);
      expect(books.first.coverImageUrl, isNull);
    });

    test('should handle missing industryIdentifiers', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'vol789',
                'volumeInfo': {
                  'title': 'No ISBN Book',
                  'authors': ['Unknown'],
                }
              }
            ]
          }),
          200,
        ),
      );

      final books = await api.search('no isbn');

      expect(books.length, 1);
      expect(books.first.isbn13, isNull);
      expect(books.first.isbn10, isNull);
    });

    test('should include apiKey, maxResults, langRestrict parameters',
        () async {
      late String requestUrl;
      final capturingClient = _CapturingClient(
        onSend: (req) async {
          requestUrl = req.url.toString();
          return http.StreamedResponse(
            Stream.fromIterable([utf8.encode(jsonEncode({}))]),
            200,
            request: req,
          );
        },
      );
      final capturingApi =
          GoogleBooksApi(apiKey: 'key', client: capturingClient);

      await capturingApi.search('Flutter');

      expect(requestUrl, contains('key=key'));
      expect(requestUrl, contains('maxResults=10'));
      expect(requestUrl, contains('langRestrict=ja'));
      expect(requestUrl, contains('q=Flutter'));
    });
  });

  group('GoogleBooksApi.lookupByIsbn', () {
    test('should return Book when found via isbn: prefix', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'vol-isbn',
                'volumeInfo': {
                  'title': 'ISBN Search Book',
                  'authors': ['ISBN Taro'],
                  'industryIdentifiers': [
                    {'type': 'ISBN_13', 'identifier': '9789999999999'},
                  ],
                }
              }
            ]
          }),
          200,
        ),
      );

      final book = await api.lookupByIsbn('9789999999999');

      expect(book, isNotNull);
      expect(book!.title, 'ISBN Search Book');
      expect(book.isbn13, '9789999999999');
      expect(book.source, BookSource.googleBooks);
    });

    test('should return null when not found', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response(jsonEncode({}), 200),
      );

      final book = await api.lookupByIsbn('0000000000000');

      expect(book, isNull);
    });

    test('should use isbn: prefix in query', () async {
      late String requestUrl;
      final capturingClient = _CapturingClient(
        onSend: (req) async {
          requestUrl = req.url.toString();
          return http.StreamedResponse(
            Stream.fromIterable([utf8.encode(jsonEncode({}))]),
            200,
            request: req,
          );
        },
      );
      final capturingApi =
          GoogleBooksApi(apiKey: 'key', client: capturingClient);

      await capturingApi.lookupByIsbn('1234567890123');

      expect(requestUrl, contains('isbn%3A1234567890123'));
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
