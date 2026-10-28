import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/reminders/domain/notification_route_resolver.dart';

const Set<String> _allowed = {'library', 'reading'};

void main() {
  group('ResolvedNotificationRoute（値オブジェクト）', () {
    test('route と id が同じなら等価', () {
      expect(
        ResolvedNotificationRoute(route: 'library', id: 'ub-1'),
        ResolvedNotificationRoute(route: 'library', id: 'ub-1'),
      );
    });

    test('id が違えば非等価（hashCode も追随する）', () {
      final a = ResolvedNotificationRoute(route: 'library', id: 'ub-1');
      final b = ResolvedNotificationRoute(route: 'library', id: 'ub-2');
      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
      expect(
        {a, ResolvedNotificationRoute(route: 'library', id: 'ub-1')}.length,
        1,
      );
    });

    test('空の route は構築時に ArgumentError（例外を握り潰さない）', () {
      expect(
        () => ResolvedNotificationRoute(route: ''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ResolvedNotificationRoute(route: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('NotificationRouteResolver.resolve', () {
    test('正常な JSON を解決する（route のみ）', () {
      final resolved = NotificationRouteResolver.resolve(
        '{"route":"library"}',
        allowedRoutes: _allowed,
      );
      expect(resolved, ResolvedNotificationRoute(route: 'library'));
      expect(resolved?.id, isNull);
    });

    test('id 付きの JSON を解決する', () {
      final resolved = NotificationRouteResolver.resolve(
        '{"route":"reading","id":"ub-42"}',
        allowedRoutes: _allowed,
      );
      expect(resolved, ResolvedNotificationRoute(route: 'reading', id: 'ub-42'));
    });

    test('null / 空文字 / 空白のみは null（例外なし）', () {
      for (final payload in <String?>[null, '', '   ']) {
        expect(
          NotificationRouteResolver.resolve(payload, allowedRoutes: _allowed),
          isNull,
          reason: 'payload=$payload',
        );
      }
    });

    test('壊れた JSON は null（例外なし）', () {
      for (final payload in <String>[
        '{"route":',
        'route=library',
        '{"route":"library"',
        'not json at all',
        '{route:"library"}',
      ]) {
        expect(
          NotificationRouteResolver.resolve(payload, allowedRoutes: _allowed),
          isNull,
          reason: 'payload=$payload',
        );
      }
    });

    test('JSON だがオブジェクトでない（配列・文字列・数値・null リテラル）は null', () {
      for (final payload in <String>[
        '[]',
        '["library"]',
        '"library"',
        '42',
        'null',
        'true',
      ]) {
        expect(
          NotificationRouteResolver.resolve(payload, allowedRoutes: _allowed),
          isNull,
          reason: 'payload=$payload',
        );
      }
    });

    test('allowedRoutes に無い route は null（未知 route は遷移しない）', () {
      expect(
        NotificationRouteResolver.resolve(
          '{"route":"settings"}',
          allowedRoutes: _allowed,
        ),
        isNull,
      );
    });

    test('allowedRoutes が空なら常に null', () {
      expect(
        NotificationRouteResolver.resolve(
          '{"route":"library"}',
          allowedRoutes: const <String>{},
        ),
        isNull,
      );
    });

    test('route キーが無い / route が文字列でない / 空文字は null', () {
      for (final payload in <String>[
        '{"id":"ub-1"}',
        '{"route":null}',
        '{"route":123}',
        '{"route":""}',
        '{"route":"   "}',
        '{"route":["library"]}',
      ]) {
        expect(
          NotificationRouteResolver.resolve(payload, allowedRoutes: _allowed),
          isNull,
          reason: 'payload=$payload',
        );
      }
    });

    test('id が文字列でない / 空文字なら null に落とす（route は生きる）', () {
      for (final payload in <String>[
        '{"route":"reading","id":123}',
        '{"route":"reading","id":null}',
        '{"route":"reading","id":""}',
        '{"route":"reading","id":{"a":1}}',
      ]) {
        final resolved = NotificationRouteResolver.resolve(
          payload,
          allowedRoutes: _allowed,
        );
        expect(resolved?.route, 'reading', reason: 'payload=$payload');
        expect(resolved?.id, isNull, reason: 'payload=$payload');
      }
    });

    test('余分なキーは無害（route/id だけを見る）', () {
      final resolved = NotificationRouteResolver.resolve(
        '{"route":"library","id":"ub-1","extra":{"nested":[1,2,3]},"v":9}',
        allowedRoutes: _allowed,
      );
      expect(resolved, ResolvedNotificationRoute(route: 'library', id: 'ub-1'));
    });
  });

  group('NotificationRouteResolver.buildPayload', () {
    test('buildPayload → resolve の往復で元の値に戻る（id なし）', () {
      final payload = NotificationRouteResolver.buildPayload('library');
      expect(
        NotificationRouteResolver.resolve(payload, allowedRoutes: _allowed),
        ResolvedNotificationRoute(route: 'library'),
      );
    });

    test('buildPayload → resolve の往復で元の値に戻る（id あり）', () {
      final payload =
          NotificationRouteResolver.buildPayload('reading', id: 'ub-9');
      expect(
        NotificationRouteResolver.resolve(payload, allowedRoutes: _allowed),
        ResolvedNotificationRoute(route: 'reading', id: 'ub-9'),
      );
    });

    test('id が空文字なら id キーを載せない', () {
      final decoded = jsonDecode(
        NotificationRouteResolver.buildPayload('library', id: ''),
      ) as Map<String, dynamic>;
      expect(decoded, {'route': 'library'});
    });

    test('route が空なら buildPayload は ArgumentError', () {
      expect(
        () => NotificationRouteResolver.buildPayload(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('JSON として妥当で、特殊文字を含む id も往復できる', () {
      const tricky = 'ub"1\\2\n3';
      final payload = NotificationRouteResolver.buildPayload('reading', id: tricky);
      expect(jsonDecode(payload), isA<Map<String, dynamic>>());
      expect(
        NotificationRouteResolver.resolve(payload, allowedRoutes: _allowed)?.id,
        tricky,
      );
    });
  });
}
