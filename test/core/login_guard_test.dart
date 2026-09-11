import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/app_router.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';

void _initTestHive() {
  final tempDir = Directory.systemTemp.createTempSync('hive_test_');
  Hive.init(tempDir.path);
}

/// 認証ゲート（GoRouter redirect）の試練
///
/// - 未ログイン: いかなる場所からも /login へリダイレクト
/// - ログイン済み: '/' 等の保護ルートを通過、/login 直行は '/' へ戻される
void main() {
  setUpAll(() {
    _initTestHive();
    SharedPreferences.setMockInitialValues({});
  });
  tearDownAll(() async {
    await Hive.close();
  });

  Widget testApp({required bool signedIn}) {
    return ProviderScope(
      child: MaterialApp.router(
        theme: ThemeData.dark(),
        routerConfig: AppRouter.createRouter(isSignedIn: () => signedIn),
      ),
    );
  }

  group('LoginGuard - 未ログイン', () {
    testWidgets('initial route / は /login へリダイレクトされる', (tester) async {
      await tester.pumpWidget(testApp(signedIn: false));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.authGoogleSignInButton), findsOneWidget);
      // 蔵書機能（書庫）へは到達できない
      expect(find.byKey(AppKeys.bookshelfScreen), findsNothing);
    });

    testWidgets('保護ルート /explore も /login へリダイレクトされる',
        (tester) async {
      final router = AppRouter.createRouter(isSignedIn: () => false);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      router.go('/explore');
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.authGoogleSignInButton), findsOneWidget);
      expect(find.byKey(AppKeys.exploreScreen), findsNothing);
    });
  });

  group('LoginGuard - ログイン済み', () {
    testWidgets('initial route / は書庫画面へ通過する', (tester) async {
      await tester.pumpWidget(testApp(signedIn: true));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.bookshelfScreen), findsOneWidget);
    });

    testWidgets('/login 直行は / へ戻される', (tester) async {
      final router = AppRouter.createRouter(isSignedIn: () => true);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      router.go('/login');
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.authGoogleSignInButton), findsNothing);
      expect(find.byKey(AppKeys.bookshelfScreen), findsOneWidget);
    });

    testWidgets('ログイン済みなら保護ルート /explore に到達できる', (tester) async {
      final router = AppRouter.createRouter(isSignedIn: () => true);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      router.go('/explore');
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.exploreScreen), findsOneWidget);
    });
  });

  group('GoRouter.of によるログイン後遷移', () {
    testWidgets('router.config に /login ルートが存在する', (tester) async {
      final router = AppRouter.createRouter(isSignedIn: () => false);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      final locations =
          router.configuration.routes.map((r) => r is GoRoute ? r.path : null);
      expect(locations, contains('/login'));
    });
  });
}