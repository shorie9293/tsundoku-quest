import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/book_shelf.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/library_search_screen.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/book_card.dart';

Book _book(String id, String title, List<String> authors, {int? pageCount}) =>
    Book(
      id: id,
      title: title,
      authors: authors,
      pageCount: pageCount,
      source: BookSource.manual,
      createdAt: '2026-01-01T00:00:00Z',
    );

UserBook _ub(
  String id,
  BookStatus status, {
  Book? book,
  String createdAt = '2026-01-01T00:00:00Z',
}) =>
    UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      book: book,
      status: status,
      medium: BookMedium.physical,
      createdAt: createdAt,
    );

BookShelf _shelf(String id, String name, List<String> userBookIds) => BookShelf(
      id: id,
      name: name,
      colorValue: 0xFF888888,
      createdAt: '2026-01-01T00:00:00Z',
      userBookIds: userBookIds,
    );

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(theme: ThemeData.dark(), home: child),
    );

void _pumpLarge(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  testWidgets('①画面表示とキー存在', (tester) async {
    final books = [
      _ub('ub-1', BookStatus.tsundoku, book: _book('b1', 'ドラゴン入門', ['山田'])),
    ];
    _pumpLarge(tester);
    await tester.pumpWidget(_wrap(LibrarySearchScreen(
      booksOverride: books,
      shelvesOverride: const [],
    )));
    await tester.pump();

    expect(find.byKey(AppKeys.librarySearchScreen), findsOneWidget);
    expect(find.text('🔍 蔵書検索'), findsOneWidget);
    expect(find.byKey(AppKeys.librarySearchField), findsOneWidget);
    expect(find.byKey(AppKeys.libraryStatusFilterChips), findsOneWidget);
    expect(find.byKey(AppKeys.libraryShelfFilterChips), findsNothing);
    expect(find.byKey(AppKeys.librarySortButton), findsOneWidget);
    expect(find.byKey(AppKeys.libraryResultCount), findsOneWidget);
    expect(find.byKey(AppKeys.libraryResultList), findsOneWidget);
    expect(find.byKey(AppKeys.libraryResetButton), findsNothing);
  });

  testWidgets('②書名検索で絞り込み＋件数更新', (tester) async {
    final books = [
      _ub('ub-1', BookStatus.tsundoku, book: _book('b1', 'ドラゴン入門', ['山田'])),
      _ub('ub-2', BookStatus.tsundoku, book: _book('b2', '魔法のレシピ', ['鈴木'])),
    ];
    _pumpLarge(tester);
    await tester.pumpWidget(_wrap(LibrarySearchScreen(
      booksOverride: books,
      shelvesOverride: const [],
    )));
    await tester.pump();

    expect(find.byType(BookCard), findsNWidgets(2));
    await tester.enterText(find.byKey(AppKeys.librarySearchField), 'ドラゴン');
    await tester.pump();

    expect(find.byType(BookCard), findsNWidgets(1));
    expect(find.text('2件'), findsNothing);
    expect(find.text('1件'), findsOneWidget);
  });

  testWidgets('③著者名検索', (tester) async {
    final books = [
      _ub('ub-1', BookStatus.tsundoku, book: _book('b1', '何かの本', ['山田太郎'])),
      _ub('ub-2', BookStatus.tsundoku, book: _book('b2', '別の本', ['鈴木次郎'])),
    ];
    _pumpLarge(tester);
    await tester.pumpWidget(_wrap(LibrarySearchScreen(
      booksOverride: books,
      shelvesOverride: const [],
    )));
    await tester.pump();

    await tester.enterText(find.byKey(AppKeys.librarySearchField), '山田');
    await tester.pump();

    expect(find.byType(BookCard), findsNWidgets(1));
    expect(find.text('何かの本'), findsOneWidget);
  });

  testWidgets('④全角英数字・大文字小文字でも一致する', (tester) async {
    final books = [
      _ub('ub-1', BookStatus.tsundoku, book: _book('b1', 'Dart ABC Guide', ['Smith'])),
    ];
    _pumpLarge(tester);
    await tester.pumpWidget(_wrap(LibrarySearchScreen(
      booksOverride: books,
      shelvesOverride: const [],
    )));
    await tester.pump();

    // 全角「ＤＡＲＴ」で検索しても normalize により一致する
    await tester.enterText(find.byKey(AppKeys.librarySearchField), 'ＤＡＲＴ');
    await tester.pump();
    expect(find.byType(BookCard), findsNWidgets(1));

    // 小文字でも一致
    await tester.enterText(find.byKey(AppKeys.librarySearchField), 'abc');
    await tester.pump();
    expect(find.byType(BookCard), findsNWidgets(1));
  });

  testWidgets('⑤状態チップで絞り込み', (tester) async {
    final books = [
      _ub('ub-1', BookStatus.tsundoku, book: _book('b1', '本A', ['著者'])),
      _ub('ub-2', BookStatus.reading, book: _book('b2', '本B', ['著者'])),
      _ub('ub-3', BookStatus.completed, book: _book('b3', '本C', ['著者'])),
    ];
    _pumpLarge(tester);
    await tester.pumpWidget(_wrap(LibrarySearchScreen(
      booksOverride: books,
      shelvesOverride: const [],
    )));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('libfilter_status_reading')));
    await tester.pump();

    expect(find.byType(BookCard), findsNWidgets(1));
    expect(find.text('1件'), findsOneWidget);

    // 複数選択（積読も追加）
    await tester.tap(find.byKey(const ValueKey('libfilter_status_tsundoku')));
    await tester.pump();
    expect(find.byType(BookCard), findsNWidgets(2));
    expect(find.text('2件'), findsOneWidget);
  });

  testWidgets('⑥棚チップで絞り込み', (tester) async {
    final books = [
      _ub('ub-1', BookStatus.tsundoku, book: _book('b1', '本A', ['著者'])),
      _ub('ub-2', BookStatus.tsundoku, book: _book('b2', '本B', ['著者'])),
    ];
    final shelves = [_shelf('shelf-1', '小説', ['ub-1'])];
    _pumpLarge(tester);
    await tester.pumpWidget(_wrap(LibrarySearchScreen(
      booksOverride: books,
      shelvesOverride: shelves,
    )));
    await tester.pump();

    expect(find.byKey(AppKeys.libraryShelfFilterChips), findsOneWidget);
    expect(find.text('すべて'), findsOneWidget);
    expect(find.text('小説'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('libfilter_shelf_shelf-1')));
    await tester.pump();

    expect(find.byType(BookCard), findsNWidgets(1));
    expect(find.text('1件'), findsOneWidget);

    // すべて に戻すと全件
    await tester.tap(find.byKey(const ValueKey('libfilter_shelf_all')));
    await tester.pump();
    expect(find.byType(BookCard), findsNWidgets(2));
  });

  testWidgets('⑦ソート切替で順序が変わる', (tester) async {
    final books = [
      _ub('ub-1', BookStatus.tsundoku,
          book: _book('b1', 'ZR', ['a'], pageCount: 100),
          createdAt: '2026-01-01T00:00:00Z'),
      _ub('ub-2', BookStatus.tsundoku,
          book: _book('b2', 'AA', ['b'], pageCount: 900),
          createdAt: '2026-02-01T00:00:00Z'),
    ];
    _pumpLarge(tester);
    await tester.pumpWidget(_wrap(LibrarySearchScreen(
      booksOverride: books,
      shelvesOverride: const [],
    )));
    await tester.pump();

    String firstCardText() {
      final card = find.byType(BookCard).first;
      final title = tester.widget<BookCard>(card).book.book!.title;
      return title;
    }

    // 既定: 追加が新しい順 → 2026-02 の b2 が先頭
    expect(firstCardText(), 'AA');

    await tester.tap(find.byKey(AppKeys.librarySortButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('libsort_titleAsc')));
    await tester.pumpAndSettle();

    // 書名順 → AA が先頭（たまたま同じだが表示ラベルが変わったことで確認）
    expect(find.text('書名順'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.librarySortButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('libsort_addedOldest')));
    await tester.pumpAndSettle();

    // 追加が古い順 → ub-1 (b1) が先頭
    expect(firstCardText(), 'ZR');
    expect(find.text('追加が古い順'), findsOneWidget);
  });

  testWidgets('⑧0件で空状態表示', (tester) async {
    final books = [
      _ub('ub-1', BookStatus.tsundoku, book: _book('b1', '本A', ['著者'])),
    ];
    _pumpLarge(tester);
    await tester.pumpWidget(_wrap(LibrarySearchScreen(
      booksOverride: books,
      shelvesOverride: const [],
    )));
    await tester.pump();

    await tester.enterText(find.byKey(AppKeys.librarySearchField), '存在しない本');
    await tester.pump();

    expect(find.byType(BookCard), findsNothing);
    expect(find.byKey(AppKeys.libraryEmptyState), findsOneWidget);
    expect(find.text('条件に合う本が見つかりません'), findsOneWidget);
  });

  testWidgets('⑨リセットで全件復帰', (tester) async {
    final books = [
      _ub('ub-1', BookStatus.tsundoku, book: _book('b1', '本A', ['著者'])),
      _ub('ub-2', BookStatus.reading, book: _book('b2', '本B', ['著者'])),
    ];
    _pumpLarge(tester);
    await tester.pumpWidget(_wrap(LibrarySearchScreen(
      booksOverride: books,
      shelvesOverride: const [],
    )));
    await tester.pump();

    await tester.enterText(find.byKey(AppKeys.librarySearchField), '本A');
    await tester.pump();
    expect(find.byType(BookCard), findsNWidgets(1));
    expect(find.byKey(AppKeys.libraryResetButton), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.libraryResetButton));
    await tester.pump();

    expect(find.byType(BookCard), findsNWidgets(2));
    expect(find.byKey(AppKeys.libraryResetButton), findsNothing);
    expect(find.text('追加が新しい順'), findsOneWidget);
  });

  testWidgets('⑩クリアボタンで検索語が消えて全件に戻る', (tester) async {
    final books = [
      _ub('ub-1', BookStatus.tsundoku, book: _book('b1', '本A', ['著者'])),
      _ub('ub-2', BookStatus.tsundoku, book: _book('b2', '本B', ['著者'])),
    ];
    _pumpLarge(tester);
    await tester.pumpWidget(_wrap(LibrarySearchScreen(
      booksOverride: books,
      shelvesOverride: const [],
    )));
    await tester.pump();

    await tester.enterText(find.byKey(AppKeys.librarySearchField), '本A');
    await tester.pump();
    expect(find.byType(BookCard), findsNWidgets(1));
    expect(find.byKey(AppKeys.librarySearchClearButton), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.librarySearchClearButton));
    await tester.pump();

    expect(find.byType(BookCard), findsNWidgets(2));
    expect(find.byKey(AppKeys.librarySearchClearButton), findsNothing);
  });

  testWidgets('⑪複合（検索+状態+棚）', (tester) async {
    final books = [
      _ub('ub-1', BookStatus.tsundoku, book: _book('b1', 'ドラゴン物語', ['山田'])),
      _ub('ub-2', BookStatus.reading, book: _book('b2', 'ドラゴン戦記', ['山田'])),
      _ub('ub-3', BookStatus.reading, book: _book('b3', 'ドラゴン外伝', ['鈴木'])),
    ];
    final shelves = [_shelf('shelf-1', '勇者棚', ['ub-1', 'ub-2'])];
    _pumpLarge(tester);
    await tester.pumpWidget(_wrap(LibrarySearchScreen(
      booksOverride: books,
      shelvesOverride: shelves,
    )));
    await tester.pump();

    // 検索 + 状態 + 棚
    await tester.enterText(find.byKey(AppKeys.librarySearchField), 'ドラゴン');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('libfilter_status_reading')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('libfilter_shelf_shelf-1')));
    await tester.pump();

    // ドラゴン3件 → reading 1件(ub-2) → 棚 shelf-1 に属する → 1件
    expect(find.byType(BookCard), findsNWidgets(1));
    expect(find.text('1件'), findsOneWidget);
    expect(find.text('3件'), findsNothing);

    // すべて の棚に戻すと棚制約が外れ、検索(ドラゴン)+状態(reading)のみ
    // → ub-2「ドラゴン戦記」と ub-3「ドラゴン外伝」の2件
    await tester.tap(find.byKey(const ValueKey('libfilter_shelf_all')));
    await tester.pump();
    expect(find.byType(BookCard), findsNWidgets(2));
    expect(find.text('2件'), findsOneWidget);
  });

  testWidgets('⑫書庫画面の検索導線ボタンで /library-search へ push する',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const BookshelfScreen(),
        ),
        GoRoute(
          path: '/library-search',
          builder: (context, state) =>
              LibrarySearchScreen(booksOverride: const [], shelvesOverride: const []),
        ),
      ],
    );
    _pumpLarge(tester);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(theme: ThemeData.dark(), routerConfig: router),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(AppKeys.librarySearchButton), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.librarySearchButton));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(AppKeys.librarySearchScreen), findsOneWidget);
  });
}

