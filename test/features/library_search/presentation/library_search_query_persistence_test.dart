import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/data/query_preferences.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/library_query.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/library_search_screen.dart';

class _FakeStore implements LibraryQueryPreferencesStore {
  _FakeStore({this.initial, this.loadFuture});

  final LibraryQuery? initial;
  final Future<LibraryQuery?>? loadFuture;
  final List<LibraryQuery> saved = <LibraryQuery>[];
  int loadCount = 0;

  @override
  Future<LibraryQuery?> load() {
    loadCount++;
    return loadFuture ?? Future<LibraryQuery?>.value(initial);
  }

  @override
  Future<void> save(LibraryQuery q) async {
    saved.add(q);
  }
}

class _ThrowingStore implements LibraryQueryPreferencesStore {
  @override
  Future<LibraryQuery?> load() async => throw StateError('load failed');
  @override
  Future<void> save(LibraryQuery q) async => throw StateError('save failed');
}

Book _book(String id, String title, {List<String> authors = const ['著者']}) =>
    Book(
      id: id,
      title: title,
      authors: authors,
      pageCount: 200,
      source: BookSource.manual,
      createdAt: '2026-01-01T00:00:00Z',
    );

final List<UserBook> _books = [
  UserBook(
    id: 'ub-1',
    userId: 'u',
    bookId: 'b1',
    book: _book('b1', 'ドラゴン入門'),
    status: BookStatus.tsundoku,
    medium: BookMedium.physical,
    createdAt: '2026-01-02T00:00:00Z',
  ),
  UserBook(
    id: 'ub-2',
    userId: 'u',
    bookId: 'b2',
    book: _book('b2', '猫の物理学'),
    status: BookStatus.completed,
    medium: BookMedium.physical,
    createdAt: '2026-01-01T00:00:00Z',
  ),
];

Widget _wrap(Widget child) =>
    ProviderScope(child: MaterialApp(theme: ThemeData.dark(), home: child));

void _pumpLarge(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

String _fieldText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(AppKeys.librarySearchField))
    .controller!
    .text;

void main() {
  group('LibrarySearchScreen 検索条件の永続化', () {
    testWidgets('保存済み sortOrder を復元して表示に反映する', (tester) async {
      _pumpLarge(tester);
      final store = _FakeStore(
          initial: const LibraryQuery(sortOrder: LibrarySortOrder.titleAsc));
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        queryPreferences: store,
      )));
      await tester.pumpAndSettle();

      expect(store.loadCount, 1);
      expect(find.text('書名順'), findsOneWidget);
      expect(find.text('追加が新しい順'), findsNothing);
    });

    testWidgets('保存済みの絞り込み・検索語も復元する', (tester) async {
      _pumpLarge(tester);
      final store = _FakeStore(
          initial: const LibraryQuery(text: '猫', statuses: {
        BookStatus.completed,
      }));
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        queryPreferences: store,
      )));
      await tester.pumpAndSettle();

      expect(_fieldText(tester), '猫');
      expect(find.text('1件'), findsOneWidget);
    });

    testWidgets('並び順の変更で即 save される', (tester) async {
      _pumpLarge(tester);
      final store = _FakeStore(initial: const LibraryQuery());
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        queryPreferences: store,
      )));
      await tester.pumpAndSettle();
      expect(store.saved, isEmpty);

      await tester.tap(find.byKey(AppKeys.librarySortButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('libsort_pagesDesc')));
      await tester.pumpAndSettle();

      expect(store.saved, isNotEmpty);
      expect(store.saved.last.sortOrder, LibrarySortOrder.pagesDesc);
    });

    testWidgets('絞り込み変更で即 save される', (tester) async {
      _pumpLarge(tester);
      final store = _FakeStore(initial: const LibraryQuery());
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        queryPreferences: store,
      )));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('libfilter_status_completed')));
      await tester.pumpAndSettle();

      expect(store.saved.last.statuses, {BookStatus.completed});
    });

    testWidgets('入力中は save せず、dispose 時に text を保存する', (tester) async {
      _pumpLarge(tester);
      final store = _FakeStore(initial: const LibraryQuery());
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        queryPreferences: store,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.librarySearchField), 'ドラゴン');
      await tester.pumpAndSettle();
      expect(store.saved, isEmpty, reason: '検索語は確定まで保存しない');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(store.saved.last.text, 'ドラゴン');
    });

    testWidgets('確定（onSubmitted）で text を保存する', (tester) async {
      _pumpLarge(tester);
      final store = _FakeStore(initial: const LibraryQuery());
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        queryPreferences: store,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.librarySearchField), '猫');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(store.saved, isNotEmpty);
      expect(store.saved.last.text, '猫');
    });

    testWidgets('ロード完了前のユーザー入力を上書きしない', (tester) async {
      _pumpLarge(tester);
      final completer = Completer<LibraryQuery?>();
      final store = _FakeStore(loadFuture: completer.future);
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        queryPreferences: store,
      )));
      await tester.pump();

      await tester.enterText(find.byKey(AppKeys.librarySearchField), '手入力');
      await tester.pump();

      completer.complete(const LibraryQuery(
          text: '保存済み', sortOrder: LibrarySortOrder.titleAsc));
      await tester.pumpAndSettle();

      expect(_fieldText(tester), '手入力');
      expect(find.text('追加が新しい順'), findsOneWidget);
    });

    testWidgets('store 未注入なら永続化せず例外も出ない（既存挙動のまま）', (tester) async {
      _pumpLarge(tester);
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppKeys.librarySortButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('libsort_titleAsc')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(AppKeys.librarySearchField), '猫');
      await tester.pumpAndSettle();

      expect(find.text('書名順'), findsOneWidget);
      expect(find.text('1件'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('store が例外を投げても画面は壊れない', (tester) async {
      _pumpLarge(tester);
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        queryPreferences: _ThrowingStore(),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.librarySortButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('libsort_titleAsc')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
