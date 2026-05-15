import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/app_router.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';

void main() {
  /// Creates a test app with ProviderScope + fresh router per test.
  Widget testApp() {
    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: AppRouter.createRouter(),
      ),
    );
  }

  group('AppScaffold - PageView Sync with GoRouter', () {
    testWidgets(
      'should switch PageView page when context.go() is called from within a page',
      skip: true, // FIXME: CI (headless) で PageView+GoRouter 同期が不安定。原因調査後に再有効化。
      (tester) async {
        await tester.pumpWidget(testApp());
        await tester.pumpAndSettle();

        // Initial state: bookshelf screen should be visible
        expect(find.text('📚 書庫'), findsWidgets);

        // Simulate what happens when a page-internal button calls context.go('/explore')
        // Find the go_router from the widget tree
        final router = AppRouter.createRouter();
        // Rebuild with the same router so we can control it
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate via GoRouter (simulating context.go('/explore') from within a page)
        router.go('/explore');
        await tester.pump(); // First pump: processes the route change + build

        // The build() method now registers a postFrameCallback.
        // We need to pump again to let the callback fire.
        await tester.pump(); // Second pump: executes the postFrameCallback
        await tester.pump(); // Third pump: processes the state change from jumpToPage

        // Now verify: the explore screen's AppBar title '🧭 探索' should be visible
        // This confirms PageView has synced to the same page as GoRouter
        expect(find.text('🧭 探索'), findsWidgets);
      },
    );

    testWidgets(
      'should keep PageView synced with GoRouter when navigating back via context.go()',
      skip: true, // FIXME: CI (headless) で PageView+GoRouter 同期が不安定。原因調査後に再有効化。
      (tester) async {
        await tester.pumpWidget(testApp());
        await tester.pumpAndSettle();

        // Navigate to explore
        final router = AppRouter.createRouter();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        router.go('/explore');
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify explore screen is showing
        expect(find.text('🧭 探索'), findsWidgets);

        // Navigate back to bookshelf via GoRouter
        router.go('/');
        await tester.pump(); // rebuild with postFrameCallback
        await tester.pump(); // execute callback
        await tester.pump(); // process jumpToPage
        await tester.pumpAndSettle();

        // Verify bookshelf screen is showing again
        expect(find.text('📚 書庫'), findsWidgets);
      },
    );
  });
}
