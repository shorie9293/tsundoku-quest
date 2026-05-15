import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tsundoku_quest/shared/repositories/openbd_api.dart';
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
  late OpenBDApi api;

  setUp(() {
    fakeClient = FakeClient();
    api = OpenBDApi(client: fakeClient);
  });

  group('OpenBDApi.lookupByIsbn', () {
    test('should return Book on successful response', () async {
      fakeClient.addResponse(
        'openbd.jp',
        http.Response.bytes(
          utf8.encode(jsonEncode([
            {
              'isbn': '9784000000000',
              'title': 'オープンBDの本',
              'author': '著者一郎',
              'publisher': 'テスト出版',
              'pubdate': '2025-01',
              'cover': 'https://example.com/cover.jpg',
            }
          ])),
          200,
        ),
      );

      final book = await api.lookupByIsbn('9784000000000');

      expect(book, isNotNull);
      expect(book!.title, 'オープンBDの本');
      expect(book.isbn13, '9784000000000');
      expect(book.authors, ['著者一郎']);
      expect(book.publisher, 'テスト出版');
      expect(book.publishedDate, '2025-01');
      expect(book.coverImageUrl, 'https://example.com/cover.jpg');
      expect(book.source, BookSource.openbd);
    });

    test('should return null when response is empty array', () async {
      fakeClient.addResponse(
        'openbd.jp',
        http.Response(
          jsonEncode(<dynamic>[]),
          200,
        ),
      );

      final book = await api.lookupByIsbn('0000000000000');

      expect(book, isNull);
    });

    test('should return null when response contains null element', () async {
      fakeClient.addResponse(
        'openbd.jp',
        http.Response(
          jsonEncode([null]),
          200,
        ),
      );

      final book = await api.lookupByIsbn('0000000000000');

      expect(book, isNull);
    });

    test('should handle multiple authors separated by comma', () async {
      fakeClient.addResponse(
        'openbd.jp',
        http.Response.bytes(
          utf8.encode(jsonEncode([
            {
              'isbn': '9781234567890',
              'title': '共著の本',
              'author': '山田太郎, 鈴木花子',
              'publisher': '共著出版',
              'pubdate': '2024-06',
              'cover': '',
            }
          ])),
          200,
        ),
      );

      final book = await api.lookupByIsbn('9781234567890');

      expect(book, isNotNull);
      expect(book!.authors, ['山田太郎', '鈴木花子']);
    });

    test('should handle missing optional fields', () async {
      fakeClient.addResponse(
        'openbd.jp',
        http.Response.bytes(
          utf8.encode(jsonEncode([
            {
              'isbn': '9789876543210',
              'title': '最小情報の本',
              'author': '',
              'publisher': '',
              'pubdate': '',
              'cover': '',
            }
          ])),
          200,
        ),
      );

      final book = await api.lookupByIsbn('9789876543210');

      expect(book, isNotNull);
      expect(book!.title, '最小情報の本');
      expect(book.publisher, isNull);
      expect(book.publishedDate, isNull);
      expect(book.coverImageUrl, isNull);
    });

    test('should call correct endpoint with isbn parameter', () async {
      late String requestUrl;
      final capturingClient = _CapturingClient(
        onSend: (req) async {
          requestUrl = req.url.toString();
          return http.StreamedResponse(
            Stream.fromIterable([utf8.encode(jsonEncode(<dynamic>[]))]),
            200,
            request: req,
          );
        },
      );
      final capturingApi = OpenBDApi(client: capturingClient);

      await capturingApi.lookupByIsbn('9784000000000');

      expect(requestUrl, contains('api.openbd.jp/v1/get'));
      expect(requestUrl, contains('isbn=9784000000000'));
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
