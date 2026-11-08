import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/search/search_history.dart';
import 'package:tsundoku_quest/core/search/search_history_chips.dart';
import 'package:tsundoku_quest/core/search/search_history_store.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/library_search_screen.dart';
import 'package:tsundoku_quest/features/history/data/reading_notes_provider.dart';
import 'package:tsundoku_quest/features/history/presentation/reading_note_search_screen.dart';

class _FakeHistoryStore implements SearchHistoryStore {
  _FakeHistoryStore({this.initial = const <String>[]});

  final List<String> initial;
  final List<SearchHistory> saved = <SearchHistory>[];
  int loadCount = 0;

  @override
  Future<SearchHistory> load() async {
    loadCount++;
    return SearchHistory(entries: initial);
  }

  @override
  Future<void> save(SearchHistory history) async {
    saved.add(history);
  }
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

UserBook _ub(String id, String title) => UserBook(
      id: id,
      userId: 'u',
      bookId: 'b-$id',
      book: _book('b-$id', title),
      status: BookStatus.tsundoku,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

final List<UserBook> _books = [
  _ub('ub-1', 'ドラゴン入門'),
  _ub('ub-2', '猫の物理学'),
];

ReadingNoteItem _note(String id, String learning) => ReadingNoteItem(
      id: id,
      userBookId: 'ub_$id',
      bookTitle: '本$id',
      learnings: [learning],
      action: '',
      favoriteQuote: null,
      createdAt: '2026-01-01T00:00:00Z',
    );

final List<ReadingNoteItem> _notes = [
  _note('n1', '猫は液体'),
  _note('n2', '犬は忠実'),
];

Widget _wrap(Widget child) =>
    ProviderScope(child: MaterialApp(theme: ThemeData.dark(), home: child));

void _pumpLarge(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// 非同期の履歴復元（マイクロタスク）を2回の pump で確定させる。
/// 不確定アニメーションを待つ pumpAndSettle は使わない。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  group('SearchHistoryChips', () {
    testWidgets('履歴が空なら何も表示しない', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: SearchHistoryChips(entries: <String>[], onSelected: _noop),
      )));
      expect(find.byType(ActionChip), findsNothing);
    });

    testWidgets('履歴を新しい順に ActionChip で並べる', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: SearchHistoryChips(entries: <String>['犬', '猫'], onSelected: _noop),
      )));
      expect(find.byType(ActionChip), findsNWidgets(2));
      expect(
        tester.getCenter(find.text('犬')).dx,
        lessThan(tester.getCenter(find.text('猫')).dx),
      );
    });

    testWidgets('チップの Key は接頭辞＋連番', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(
        body: SearchHistoryChips(
          entries: <String>['犬', '猫'],
          keyPrefix: 'my_chip',
          onSelected: _noop,
        ),
      )));
      expect(find.byKey(const ValueKey('my_chip_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('my_chip_1')), findsOneWidget);
    });

    testWidgets('タップで選択した語を onSelected へ渡す', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(_wrap(Scaffold(
        body: SearchHistoryChips(
          entries: const <String>['犬', '猫'],
          onSelected: selected.add,
        ),
      )));
      await tester.tap(find.byKey(const ValueKey('search_history_chip_1')));
      await tester.pump();
      expect(selected, ['猫']);
    });
  });

  group('LibrarySearchScreen への配線', () {
    testWidgets('注入した履歴を検索欄の直下に表示する', (tester) async {
      _pumpLarge(tester);
      final store = _FakeHistoryStore(initial: const ['猫', 'ドラゴン']);
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        searchHistoryStore: store,
      )));
      await _settle(tester);

      expect(store.loadCount, 1);
      expect(find.byKey(AppKeys.librarySearchHistoryChips), findsOneWidget);
      expect(find.widgetWithText(ActionChip, '猫'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'ドラゴン'), findsOneWidget);
      // 結果は未絞り込みのまま
      expect(find.text('2件'), findsOneWidget);
    });

    testWidgets('履歴が空ならチップは表示しない', (tester) async {
      _pumpLarge(tester);
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: const <UserBook>[],
        shelvesOverride: const [],
        searchHistoryStore: _FakeHistoryStore(),
      )));
      await _settle(tester);
      expect(find.byKey(AppKeys.librarySearchHistoryChips), findsNothing);
    });

    testWidgets('チップタップで controller と query が更新され結果が再計算される',
        (tester) async {
      _pumpLarge(tester);
      final store = _FakeHistoryStore(initial: const ['猫']);
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        searchHistoryStore: store,
      )));
      await _settle(tester);
      expect(find.text('2件'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('libhistory_chip_0')));
      await tester.pump();

      final field =
          tester.widget<TextField>(find.byKey(AppKeys.librarySearchField));
      expect(field.controller!.text, '猫');
      expect(find.text('1件'), findsOneWidget);
      expect(find.text('猫の物理学'), findsOneWidget);
    });

    testWidgets('確定（onSubmitted）で現在語を履歴へ積んで保存する', (tester) async {
      _pumpLarge(tester);
      final store = _FakeHistoryStore(initial: const ['猫']);
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        searchHistoryStore: store,
      )));
      await _settle(tester);

      await tester.enterText(
          find.byKey(AppKeys.librarySearchField), '  ドラゴン  ');
      await tester.pump();
      expect(store.saved, isEmpty, reason: '入力中は履歴へ積まない');

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);

      expect(store.saved, isNotEmpty);
      expect(store.saved.last.entries.first, 'ドラゴン');
      expect(store.saved.last.entries, ['ドラゴン', '猫']);
      expect(find.widgetWithText(ActionChip, 'ドラゴン'), findsOneWidget);
    });

    testWidgets('空語では履歴を保存しない', (tester) async {
      _pumpLarge(tester);
      final store = _FakeHistoryStore();
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        searchHistoryStore: store,
      )));
      await _settle(tester);

      await tester.enterText(find.byKey(AppKeys.librarySearchField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await _settle(tester);

      expect(store.saved, isEmpty);
    });

    testWidgets('dispose 時に現在語を保存する', (tester) async {
      _pumpLarge(tester);
      final store = _FakeHistoryStore(initial: const ['猫']);
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        searchHistoryStore: store,
      )));
      await _settle(tester);

      await tester.enterText(find.byKey(AppKeys.librarySearchField), '犬');
      await _settle(tester);
      expect(store.saved, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await _settle(tester);

      expect(store.saved, isNotEmpty);
      expect(store.saved.last.entries, ['犬', '猫']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('store 未注入でも SharedPreferences 実装で壊れない', (tester) async {
      _pumpLarge(tester);
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
      )));
      await _settle(tester);

      await tester.enterText(find.byKey(AppKeys.librarySearchField), '猫');
      await tester.pump();
      expect(find.text('1件'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('ReadingNoteSearchScreen への配線', () {
    testWidgets('注入した履歴を表示し、チップタップで絞り込む', (tester) async {
      _pumpLarge(tester);
      final store = _FakeHistoryStore(initial: const ['忠実']);
      await tester.pumpWidget(_wrap(ReadingNoteSearchScreen(
        notesOverride: _notes,
        searchHistoryStore: store,
      )));
      await _settle(tester);

      expect(find.byKey(AppKeys.readingNoteSearchHistoryChips), findsOneWidget);
      expect(find.text('2件'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, '忠実'));
      await tester.pump();

      final field = tester
          .widget<TextField>(find.byKey(AppKeys.readingNoteSearchField));
      expect(field.controller!.text, '忠実');
      expect(find.text('1件'), findsOneWidget);
    });

    testWidgets('確定で保存し、dispose でも現在語を保存する', (tester) async {
      _pumpLarge(tester);
      final store = _FakeHistoryStore();
      await tester.pumpWidget(_wrap(ReadingNoteSearchScreen(
        notesOverride: _notes,
        searchHistoryStore: store,
      )));
      await _settle(tester);
      expect(find.byKey(AppKeys.readingNoteSearchHistoryChips), findsNothing);

      await tester.enterText(
          find.byKey(AppKeys.readingNoteSearchField), '液体');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      expect(store.saved.last.entries, ['液体']);
      expect(find.widgetWithText(ActionChip, '液体'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await _settle(tester);
      expect(store.saved.last.entries.first, '液体');
      expect(tester.takeException(), isNull);
    });
  });
}

void _noop(String value) {}
