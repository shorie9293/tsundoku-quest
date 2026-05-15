import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/app_router.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';

void main() {
  // Helper to create a test app with ProviderScope + fresh router per test
  Widget testApp() {
    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: AppRouter.createRouter(),
      ),
    );
  }

  group('AppRouter - Initial Route', () {
    testWidgets('should show bookshelf screen at /', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      // Bookshelf screen title appears in AppBar and body (2 texts)
      expect(find.text('書庫'), findsWidgets);
      expect(find.byKey(AppKeys.bookshelfScreen), findsOneWidget);
    });
  });

  group('AppRouter - Route Navigation', () {
    testWidgets('should navigate to /explore via tab tap', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.tabExplore));
      await tester.pumpAndSettle();

      expect(find.text('探索'), findsWidgets);
      expect(find.byKey(AppKeys.exploreScreen), findsOneWidget);
    });

    testWidgets('should navigate to /reading route directly', (tester) async {
      // /reading is now outside ShellRoute — test via direct navigation
      final router = AppRouter.createRouter();

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();

      router.go('/reading?id=test-book-id');
      await tester.pumpAndSettle();

      // ReadingScreen should be displayed without BottomNav
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('should navigate to /history via tab tap', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.tabHistory));
      await tester.pumpAndSettle();

      expect(find.text('足跡'), findsWidgets);
      expect(find.byKey(AppKeys.historyScreen), findsOneWidget);
    });
  });

  group('AppScaffold - BottomNavigationBar', () {
    testWidgets('should display BottomNavigationBar with 3 tabs',
        (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      // Find the BottomNavigationBar
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Find all 3 tab items (読書中タブ削除)
      expect(find.byKey(AppKeys.mainTabBar), findsOneWidget);
      expect(find.byKey(AppKeys.bookshelfScreen), findsOneWidget);
      expect(find.byKey(AppKeys.tabExplore), findsOneWidget);
      expect(find.byKey(AppKeys.tabHistory), findsOneWidget);
      // reading tab should NOT exist anymore
      expect(find.byKey(AppKeys.tabReading), findsNothing);
      // reading BottomNav label should not appear
      expect(find.text('読書中'), findsNothing);
    });

    testWidgets('should navigate when tapping tab icons', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      // Initial route is /, bookshelf should be visible
      expect(find.text('書庫'), findsWidgets);

      // Tap the Explore tab
      await tester.tap(find.byKey(AppKeys.tabExplore));
      await tester.pumpAndSettle();

      // Should now show explore screen
      expect(find.text('探索'), findsWidgets);

      // Tap the History tab
      await tester.tap(find.byKey(AppKeys.tabHistory));
      await tester.pumpAndSettle();

      expect(find.text('足跡'), findsWidgets);

      // Tap back to Bookshelf
      await tester.tap(find.byKey(AppKeys.tabBookshelf));
      await tester.pumpAndSettle();

      expect(find.text('書庫'), findsWidgets);
    });

    testWidgets('should set correct selected index for each route',
        (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      // At /, bookshelf tab (index 0) should be selected
      BottomNavigationBar navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBar.currentIndex, 0);

      // Navigate to /explore by tapping the tab
      await tester.tap(find.byKey(AppKeys.tabExplore));
      await tester.pumpAndSettle();

      navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBar.currentIndex, 1);

      // Navigate to /history by tapping the tab (now index 2, no reading tab)
      await tester.tap(find.byKey(AppKeys.tabHistory));
      await tester.pumpAndSettle();

      navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(navBar.currentIndex, 2);
    });
  });

  group('AppScaffold - Accessibility', () {
    testWidgets('should have Semantics on tab items', (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();

      // Semantics widgets should exist wrapping the navigation items
      expect(find.byType(Semantics), findsWidgets);

      // Check for navigation-related Semantics identifiers
      final semanticsList = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );

      // At least one Semantics node should have a navigation identifier
      var hasNavSemantics = false;
      for (final s in semanticsList) {
        final identifier = s.properties.identifier;
        if (identifier != null && identifier.startsWith('nav_')) {
          hasNavSemantics = true;
          break;
        }
      }
      expect(hasNavSemantics, isTrue);
    });
  });
}
