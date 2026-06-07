import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tsundoku_quest/app_router.dart';

void main() {
  group('AppRouter', () {
    test('router singleton is not null and is a GoRouter', () {
      expect(AppRouter.router, isNotNull);
      expect(AppRouter.router, isA<GoRouter>());
    });

    test('createRouter returns a GoRouter', () {
      final router = AppRouter.createRouter();
      expect(router, isNotNull);
      expect(router, isA<GoRouter>());
    });
  });
}