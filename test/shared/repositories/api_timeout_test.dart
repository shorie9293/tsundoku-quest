import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tsundoku_quest/shared/repositories/google_books_api.dart';
import 'package:tsundoku_quest/shared/repositories/openbd_api.dart';
import 'package:tsundoku_quest/shared/repositories/rakuten_api.dart';

/// 応答を一切返さない（パケット黒穴を模した）クライアント。
///
/// 圏外・機内モード・DNS不達・接続先の無応答では Future が完了しないため、
/// `.timeout()` が無いと画面のスピナーが永久に回る。
http.Client hangingClient(void Function() onCall) {
  return MockClient((request) {
    onCall();
    return Completer<http.Response>().future;
  });
}

void main() {
  group('RakutenApi のタイムアウト', () {
    test('search は応答が無いとき TimeoutException で失敗する', () async {
      var calls = 0;
      final api = RakutenApi(
        appId: 'dummy',
        accessKey: 'dummy',
        client: hangingClient(() => calls++),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        api.search('積読'),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, 1, reason: '1回の呼出で1回だけ問い合わせる（自動リトライしない）');
    });

    test('lookupByIsbn も同じく TimeoutException で失敗する', () async {
      final api = RakutenApi(
        appId: 'dummy',
        accessKey: 'dummy',
        client: hangingClient(() {}),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        api.lookupByIsbn('9784000000000'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('応答が返ればタイムアウトは発火しない（既存経路の回帰）', () async {
      final api = RakutenApi(
        appId: 'dummy',
        accessKey: 'dummy',
        client: MockClient((_) async => http.Response(
              jsonEncode({'Items': []}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            )),
        timeout: const Duration(milliseconds: 50),
      );

      expect(await api.search('積読'), isEmpty);
    });

    test('再試行は呼び出し側の2回目で再度問い合わせる', () async {
      var calls = 0;
      final api = RakutenApi(
        appId: 'dummy',
        accessKey: 'dummy',
        client: hangingClient(() => calls++),
        timeout: const Duration(milliseconds: 30),
      );

      await expectLater(
        api.search('積読'),
        throwsA(isA<TimeoutException>()),
      );
      await expectLater(
        api.search('積読'),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, 2);
    });
  });

  group('OpenBDApi のタイムアウト', () {
    test('lookupByIsbn は応答が無いとき TimeoutException で失敗する', () async {
      final api = OpenBDApi(
        client: hangingClient(() {}),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        api.lookupByIsbn('9784000000000'),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('GoogleBooksApi のタイムアウト', () {
    test('search は時間切れを isTimeout 付きの例外で返す', () async {
      final api = GoogleBooksApi(
        apiKey: 'dummy',
        client: hangingClient(() {}),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        api.search('積読'),
        throwsA(
          isA<GoogleBooksException>()
              .having((e) => e.isTimeout, 'isTimeout', isTrue),
        ),
      );
    });

    test('lookupByIsbn も時間切れを isTimeout 付きの例外で返す', () async {
      final api = GoogleBooksApi(
        apiKey: 'dummy',
        client: hangingClient(() {}),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        api.lookupByIsbn('9784000000000'),
        throwsA(
          isA<GoogleBooksException>()
              .having((e) => e.isTimeout, 'isTimeout', isTrue),
        ),
      );
    });

    test('trySearch は時間切れを LoadResult.failure として返す', () async {
      final api = GoogleBooksApi(
        apiKey: 'dummy',
        client: hangingClient(() {}),
        timeout: const Duration(milliseconds: 50),
      );

      final result = await api.trySearch('積読');
      expect(result.isFailure, isTrue);
      expect(result.message, isNotNull);
      expect(
        result.cause,
        isA<GoogleBooksException>()
            .having((e) => e.isTimeout, 'isTimeout', isTrue),
      );
    });
  });
}
