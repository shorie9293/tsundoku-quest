import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/features/explore/presentation/explore_screen.dart';
import 'package:tsundoku_quest/shared/load_state.dart';
import 'package:tsundoku_quest/shared/providers/book_search_service_provider.dart';
import 'package:tsundoku_quest/shared/repositories/book_search_service.dart';
import 'package:tsundoku_quest/shared/repositories/google_books_api.dart';
import 'package:tsundoku_quest/shared/repositories/openbd_api.dart';
import 'package:tsundoku_quest/shared/repositories/rakuten_api.dart';

Widget _screenWith(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/explore',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen()),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: ThemeData.dark(),
      routerConfig: router,
    ),
  );
}

Book _book(String title) => Book(
      id: 'id-$title',
      title: title,
      authors: const ['著者'],
      source: BookSource.googleBooks,
      createdAt: '2026-01-01T00:00:00Z',
    );

/// trySearch を台本どおり返し、呼出回数を数えるテストダブル。
class _ScriptedSearchService extends BookSearchService {
  _ScriptedSearchService(this.script)
      : super(
          rakuten: RakutenApi(appId: '', accessKey: ''),
          openbd: OpenBDApi(),
          googleBooks: GoogleBooksApi(apiKey: 'test-key'),
        );

  final List<LoadResult<List<Book>>> script;
  int calls = 0;

  @override
  Future<LoadResult<List<Book>>> trySearch(String query) async {
    final index = calls < script.length ? calls : script.length - 1;
    calls++;
    return script[index];
  }
}

void main() {
  late _ScriptedSearchService service;

  ProviderContainer containerWith(_ScriptedSearchService s) {
    final container = ProviderContainer(
      overrides: [bookSearchServiceProvider.overrideWith((ref) => s)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byKey(AppKeys.searchField), query);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  group('検索の読込失敗と0件の分離', () {
    testWidgets('失敗時はエラー表示が出て、0件表示は出ない', (tester) async {
      service = _ScriptedSearchService([
        LoadResult.failure('読み込みに失敗しました'),
      ]);
      await tester.pumpWidget(_screenWith(containerWith(service)));

      await search(tester, '通信断');

      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
      expect(find.text('検索結果が見つかりませんでした'), findsNothing);
    });

    testWidgets('0件時は0件表示が出て、エラー表示は出ない', (tester) async {
      service = _ScriptedSearchService([LoadResult.success(const <Book>[])]);
      await tester.pumpWidget(_screenWith(containerWith(service)));

      await search(tester, '存在しない本');

      expect(find.byKey(const ValueKey('load_empty_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.text('検索結果が見つかりませんでした'), findsOneWidget);
    });

    testWidgets('エラー文言と0件文言は別物', (tester) async {
      service = _ScriptedSearchService([
        LoadResult.failure('読み込みに失敗しました'),
      ]);
      await tester.pumpWidget(_screenWith(containerWith(service)));
      await search(tester, '通信断');

      expect(find.text('読み込みに失敗しました'), findsOneWidget);
      expect(find.text('検索結果が見つかりませんでした'), findsNothing);
    });

    testWidgets('再試行タップで検索が2回目実行される（1→2）', (tester) async {
      service = _ScriptedSearchService([
        LoadResult.failure('読み込みに失敗しました'),
        LoadResult.success([_book('再試行で見つかった本')]),
      ]);
      await tester.pumpWidget(_screenWith(containerWith(service)));

      await search(tester, '再試行');
      expect(service.calls, 1);
      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('load_retry_button')));
      await tester.pumpAndSettle();

      expect(service.calls, 2);
    });

    testWidgets('成功するとエラー表示が消えて結果が出る', (tester) async {
      service = _ScriptedSearchService([
        LoadResult.failure('読み込みに失敗しました'),
        LoadResult.success([_book('復帰した本')]),
      ]);
      await tester.pumpWidget(_screenWith(containerWith(service)));

      await search(tester, '復帰');
      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('load_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.text('復帰した本'), findsOneWidget);
    });

    testWidgets('成功時はエラー表示も0件表示も出ない', (tester) async {
      service = _ScriptedSearchService([
        LoadResult.success([_book('見つかった本')]),
      ]);
      await tester.pumpWidget(_screenWith(containerWith(service)));

      await search(tester, '見つかる');

      expect(find.text('見つかった本'), findsOneWidget);
      expect(find.byKey(const ValueKey('load_error_view')), findsNothing);
      expect(find.byKey(const ValueKey('load_empty_view')), findsNothing);
    });

    testWidgets('retryable=false なら再試行ボタンを出さない', (tester) async {
      service = _ScriptedSearchService([
        LoadResult.failure('この検索は提供終了しました', retryable: false),
      ]);
      await tester.pumpWidget(_screenWith(containerWith(service)));

      await search(tester, '提供終了');

      expect(find.byKey(const ValueKey('load_error_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('load_retry_button')), findsNothing);
    });
  });
}
