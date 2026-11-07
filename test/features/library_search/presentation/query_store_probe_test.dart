// 親探針: **本番と同じ SharedPreferences ストア**を通した往復を撃つ。
//
// 子の試練はフェイクの store を注入して復元・保存のタイミングだけを検証する。
// ここでは本番キー・本番ストア実装・画面配線の合成を、2画面（本棚検索・
// 読書メモ検索）について実測する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/data/query_preferences.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/library_search_screen.dart';
import 'package:tsundoku_quest/features/history/presentation/reading_note_search_screen.dart';

Book _book(String id, String title) => Book(
      id: id,
      title: title,
      authors: const ['著者'],
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

void _largeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('本棚検索: 画面Aの条件が画面Bへ復元される（往復）', (tester) async {
    _largeView(tester);
    const store = SharedPreferencesLibraryQueryPreferencesStore();

    Future<void> pumpScreen() async {
      await tester.pumpWidget(_wrap(LibrarySearchScreen(
        booksOverride: _books,
        shelvesOverride: const [],
        queryPreferences: store,
      )));
      await tester.pumpAndSettle();
    }

    // 画面A: 並び順と検索語を変える
    await pumpScreen();
    await tester.tap(find.byKey(AppKeys.librarySortButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('libsort_titleAsc')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.librarySearchField), 'ドラゴン');
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      SharedPreferencesLibraryQueryPreferencesStore.key,
    );
    expect(raw, isNotNull);
    expect(raw, contains('titleAsc'));

    // 画面B: 開き直すと復元されている
    await pumpScreen();
    expect(find.text('書名順'), findsOneWidget);
    final field = tester
        .widget<TextField>(find.byKey(AppKeys.librarySearchField))
        .controller;
    expect(field?.text, 'ドラゴン');
    expect(find.text('1件'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('読書メモ検索: 本番ストアで往復し、壊れた値でも既定で開く', (tester) async {
    _largeView(tester);
    const store = SharedPreferencesReadingNoteQueryPreferencesStore();

    // 保存値が壊れている場合 → 既定条件・例外なし
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesReadingNoteQueryPreferencesStore.key: '{壊れた',
    });
    await tester.pumpWidget(_wrap(ReadingNoteSearchScreen(
      notesOverride: const [],
      queryPreferences: store,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.readingNoteSearchScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 正常往復: 検索語を入れて閉じ、開き直して復元される
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_wrap(ReadingNoteSearchScreen(
      notesOverride: const [],
      queryPreferences: store,
    )));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(AppKeys.readingNoteSearchField), '面白かった');
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      SharedPreferencesReadingNoteQueryPreferencesStore.key,
    );
    expect(raw, isNotNull);

    await tester.pumpWidget(_wrap(ReadingNoteSearchScreen(
      notesOverride: const [],
      queryPreferences: store,
    )));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextField>(find.byKey(AppKeys.readingNoteSearchField))
        .controller;
    expect(controller?.text, '面白かった');
    expect(tester.takeException(), isNull);
  });
}
