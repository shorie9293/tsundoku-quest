import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/shared/repositories/google_books_api.dart';

/// URL 部分一致でレスポンスを返す偽クライアント。
class FakeClient extends http.BaseClient {
  final Map<String, http.Response> _routeMap = {};
  int callCount = 0;
  Object? throwOnSend;

  void addResponse(String urlContains, http.Response response) {
    _routeMap[urlContains] = response;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    if (throwOnSend != null) throw throwOnSend!;
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
      request: request,
      headers: resp.headers,
    );
  }
}

Map<String, dynamic> _bookJson(String title) => {
      'items': [
        {
          'id': 'vol-$title',
          'volumeInfo': {
            'title': title,
            'authors': ['著者'],
          },
        }
      ]
    };

void main() {
  late FakeClient fakeClient;
  late GoogleBooksApi api;

  setUp(() {
    fakeClient = FakeClient();
    api = GoogleBooksApi(apiKey: 'test-key', client: fakeClient);
  });

  group('GoogleBooksApi.trySearch', () {
    test('HTTP 200 で書籍ありなら success(リスト)', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response(jsonEncode(_bookJson('読める本')), 200,
            headers: {'content-type': 'application/json; charset=utf-8'}),
      );

      final result = await api.trySearch('読める本');

      expect(result.isSuccess, isTrue);
      expect(result.message, isNull);
      expect(result.valueOrNull, hasLength(1));
      expect(result.valueOrNull!.first.title, '読める本');
      expect(result.valueOrNull!.first.source, BookSource.googleBooks);
    });

    test('HTTP 200 かつ 0件なら success(空リスト)', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response(jsonEncode(<String, dynamic>{}), 200),
      );

      final result = await api.trySearch('存在しない本');

      expect(result.isSuccess, isTrue, reason: '0件は失敗ではない');
      expect(result.valueOrNull, isEmpty);
    });

    test('HTTP 500 は failure', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response('server error', 500),
      );

      final result = await api.trySearch('何か');

      expect(result.isFailure, isTrue);
      expect(result.message, isNotNull);
      expect(result.message, contains('500'));
      expect(result.retryable, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('HTTP 429 も failure（0件と混同しない）', () async {
      fakeClient.addResponse('googleapis.com', http.Response('', 429));

      final result = await api.trySearch('何か');

      expect(result.isFailure, isTrue);
      expect(result.message, contains('429'));
    });

    test('通信例外は failure（握り潰さない）', () async {
      fakeClient.throwOnSend = const SocketErrorStub();

      final result = await api.trySearch('何か');

      expect(result.isFailure, isTrue);
      expect(result.cause, isA<SocketErrorStub>());
      expect(result.message, isNotNull);
    });

    test('JSON 不正は failure', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response('not json', 200),
      );

      final result = await api.trySearch('何か');

      expect(result.isFailure, isTrue);
    });

    test('既存 search は後方互換で HTTP 500 のとき空リスト', () async {
      fakeClient.addResponse('googleapis.com', http.Response('', 500));

      expect(await api.search('何か'), isEmpty);
    });
  });

  group('GoogleBooksApi.trySearchByIsbn', () {
    test('HTTP 200 で該当ありなら success(Book)', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response(jsonEncode(_bookJson('ISBN本')), 200,
            headers: {'content-type': 'application/json; charset=utf-8'}),
      );

      final result = await api.trySearchByIsbn('9784111111111');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNotNull);
      expect(result.valueOrNull!.title, 'ISBN本');
    });

    test('HTTP 200 かつ 0件なら success(null)', () async {
      fakeClient.addResponse(
        'googleapis.com',
        http.Response(jsonEncode(<String, dynamic>{}), 200),
      );

      final result = await api.trySearchByIsbn('9784111111111');

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('HTTP 500 は failure', () async {
      fakeClient.addResponse('googleapis.com', http.Response('', 500));

      final result = await api.trySearchByIsbn('9784111111111');

      expect(result.isFailure, isTrue);
      expect(result.message, contains('500'));
    });

    test('通信例外は failure', () async {
      fakeClient.throwOnSend = Exception('offline');

      final result = await api.trySearchByIsbn('9784111111111');

      expect(result.isFailure, isTrue);
    });

    test('既存 lookupByIsbn は後方互換で HTTP 500 のとき null', () async {
      fakeClient.addResponse('googleapis.com', http.Response('', 500));

      expect(await api.lookupByIsbn('9784111111111'), isNull);
    });
  });
}

/// SocketException 相当のダミー（dart:io 依存を避ける）。
class SocketErrorStub implements Exception {
  const SocketErrorStub();
}
