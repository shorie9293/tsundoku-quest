import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tsundoku_quest/features/explore/presentation/explore_screen.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';
import 'package:tsundoku_quest/shared/providers/book_search_service_provider.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/shared/repositories/book_search_service.dart';
import 'package:tsundoku_quest/shared/repositories/rakuten_api.dart';
import 'package:tsundoku_quest/shared/repositories/openbd_api.dart';
import 'package:tsundoku_quest/shared/repositories/google_books_api.dart';

Widget testExploreScreen() => ProviderScope(
      child: MaterialApp(theme: ThemeData.dark(), home: const ExploreScreen()),
    );

/// Creates a test widget with GoRouter support for navigation
Widget testExploreScreenWithRouter({ProviderContainer? container}) {
  final router = GoRouter(
    initialLocation: '/explore',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      GoRoute(
        path: '/explore',
        builder: (_, __) => const ExploreScreen(),
      ),
    ],
  );

  final app = MaterialApp.router(
    theme: ThemeData.dark(),
    routerConfig: router,
  );

  if (container != null) {
    return UncontrolledProviderScope(container: container, child: app);
  }
  return ProviderScope(child: app);
}

void main() {
  group('ExploreScreen', () {
    testWidgets('should display app bar', (tester) async {
      await tester.pumpWidget(testExploreScreen());
      expect(find.text('🧭 探索'), findsOneWidget);
    });

    testWidgets('should show three tab buttons', (tester) async {
      await tester.pumpWidget(testExploreScreen());
      expect(find.text('🔍 検索'), findsOneWidget);
      expect(find.text('📷 スキャン'), findsOneWidget);
      expect(find.text('✏️ 手入力'), findsOneWidget);
    });

    testWidgets('should show search field by default', (tester) async {
      await tester.pumpWidget(testExploreScreen());
      expect(find.byKey(AppKeys.searchField), findsOneWidget);
    });

    testWidgets('should show manual form when manual tab tapped',
        (tester) async {
      await tester.pumpWidget(testExploreScreen());
      await tester.tap(find.text('✏️ 手入力'));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.manualTitleField), findsOneWidget);
      expect(find.byKey(AppKeys.manualSubmit), findsOneWidget);
    });

    testWidgets('should accept text input in manual form', (tester) async {
      await tester.pumpWidget(testExploreScreen());
      await tester.tap(find.text('✏️ 手入力'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(AppKeys.manualTitleField), 'Test Book');
      await tester.enterText(find.byKey(AppKeys.manualAuthorField), 'Author');
      expect(find.text('Test Book'), findsOneWidget);
    });
    testWidgets('should create UserBook when manual submit with title',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        testExploreScreenWithRouter(container: container),
      );

      // Navigate to manual tab
      await tester.tap(find.text('✏️ 手入力'));
      await tester.pumpAndSettle();

      // Enter title and submit
      await tester.enterText(find.byKey(AppKeys.manualTitleField), 'テストの本');
      await tester.tap(find.byKey(AppKeys.manualSubmit));
      await tester.pumpAndSettle();

      // Verify a UserBook was created with tsundoku status
      final userBooks = container.read(bookDataProvider).userBooks;
      expect(userBooks.length, 1);
      expect(userBooks.first.status, BookStatus.tsundoku);
      expect(userBooks.first.book?.title, 'テストの本');
    });

    testWidgets('should show scan guide text when scan tab selected',
        (tester) async {
      await tester.pumpWidget(testExploreScreen());
      await tester.tap(find.text('📷 スキャン'));
      await tester.pumpAndSettle();

      expect(
        find.text('枠内にバーコードをかざしてください'),
        findsOneWidget,
      );
    });

    testWidgets('should show scan window frame when scan tab selected',
        (tester) async {
      await tester.pumpWidget(testExploreScreen());
      await tester.tap(find.text('📷 スキャン'));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.scanFrame), findsOneWidget);
    });
  });

  group('ExploreScreen search', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          bookSearchServiceProvider.overrideWithProvider(
            Provider<BookSearchService>((ref) => _MockBookSearchService()),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    testWidgets('should call search service on submitted and show results',
        (tester) async {
      await tester.pumpWidget(
        testExploreScreenWithRouter(container: container),
      );

      await tester.enterText(find.byKey(AppKeys.searchField), 'テスト');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(); // triggers async gap

      // Wait for search to complete
      await tester.pumpAndSettle();

      expect(find.text('検索結果1'), findsOneWidget);
      expect(find.text('検索結果2'), findsOneWidget);
    });

    testWidgets('should show CircularProgressIndicator while searching',
        (tester) async {
      await tester.pumpWidget(
        testExploreScreenWithRouter(container: container),
      );

      await tester.enterText(find.byKey(AppKeys.searchField), 'テスト');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      // First pump: process microtask from receiveAction → onSubmitted fires
      await tester.pump();
      // Second pump: rebuild after setState sets _isSearching = true
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('should show SnackBar on search error', (tester) async {
      await tester.pumpWidget(
        testExploreScreenWithRouter(container: container),
      );

      await tester.enterText(find.byKey(AppKeys.searchField), 'error');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.textContaining('検索エラー'), findsOneWidget);
    });

    testWidgets('should ignore empty query on submitted', (tester) async {
      await tester.pumpWidget(
        testExploreScreenWithRouter(container: container),
      );

      await tester.enterText(find.byKey(AppKeys.searchField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should still show the initial prompt, not a spinner
      expect(find.text('本を検索してください'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('should show empty results message when no books found',
        (tester) async {
      final noResultsContainer = ProviderContainer(
        overrides: [
          bookSearchServiceProvider.overrideWithProvider(
            Provider<BookSearchService>((ref) => _MockEmptyBookSearchService()),
          ),
        ],
      );
      addTearDown(noResultsContainer.dispose);

      await tester.pumpWidget(
        testExploreScreenWithRouter(container: noResultsContainer),
      );

      await tester.enterText(find.byKey(AppKeys.searchField), '存在しない本');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('検索結果が見つかりませんでした'), findsOneWidget);
    });
  });
}

class _MockBookSearchService extends BookSearchService {
  _MockBookSearchService()
      : super(
          rakuten: RakutenApi(appId: '', accessKey: ''),
          openbd: OpenBDApi(),
          googleBooks: GoogleBooksApi(apiKey: ''),
        );

  @override
  Future<List<Book>> search(String query) async {
    if (query == 'error') throw Exception('API error');
    // Yield microtask to allow spinner state to render
    await Future<void>.delayed(Duration.zero);
    return [
      Book(
        id: '1',
        title: '検索結果1',
        authors: ['著者1'],
        source: BookSource.rakuten,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
      Book(
        id: '2',
        title: '検索結果2',
        authors: ['著者2'],
        source: BookSource.rakuten,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    ];
  }
}

class _MockEmptyBookSearchService extends BookSearchService {
  _MockEmptyBookSearchService()
      : super(
          rakuten: RakutenApi(appId: '', accessKey: ''),
          openbd: OpenBDApi(),
          googleBooks: GoogleBooksApi(apiKey: ''),
        );

  @override
  Future<List<Book>> search(String query) async {
    return [];
  }
}
