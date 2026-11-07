import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/bookshelf/data/query_preferences.dart';
import 'package:tsundoku_quest/features/history/data/reading_notes_provider.dart';
import 'package:tsundoku_quest/features/history/domain/reading_note_query.dart';
import 'package:tsundoku_quest/features/history/presentation/reading_note_search_screen.dart';

class _FakeStore implements ReadingNoteQueryPreferencesStore {
  _FakeStore({this.initial, this.loadFuture});

  final ReadingNoteQuery? initial;
  final Future<ReadingNoteQuery?>? loadFuture;
  final List<ReadingNoteQuery> saved = <ReadingNoteQuery>[];
  int loadCount = 0;

  @override
  Future<ReadingNoteQuery?> load() {
    loadCount++;
    return loadFuture ?? Future<ReadingNoteQuery?>.value(initial);
  }

  @override
  Future<void> save(ReadingNoteQuery q) async {
    saved.add(q);
  }
}

ReadingNoteItem _note(
  String id, {
  String? bookTitle,
  List<String> learnings = const [],
  String action = '',
  String createdAt = '2026-01-01T00:00:00Z',
}) =>
    ReadingNoteItem(
      id: id,
      userBookId: 'ub_$id',
      bookTitle: bookTitle,
      learnings: learnings,
      action: action,
      createdAt: createdAt,
    );

final List<ReadingNoteItem> _notes = [
  _note('n1', bookTitle: '吾輩は猫である', learnings: ['主観'], action: '疑う'),
  _note('n2', bookTitle: '坊っちゃん', learnings: [], action: ''),
  _note('n3', bookTitle: '坊っちゃん', learnings: ['正義'], action: '怒る'),
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
    .widget<TextField>(find.byKey(AppKeys.readingNoteSearchField))
    .controller!
    .text;

void main() {
  group('ReadingNoteSearchScreen 検索条件の永続化', () {
    testWidgets('保存済み条件を復元する（並び順・書名・検索語）', (tester) async {
      _pumpLarge(tester);
      final store = _FakeStore(
          initial: const ReadingNoteQuery(
        text: '坊っちゃん',
        bookTitles: {'坊っちゃん'},
        contentFilters: {ReadingNoteContentFilter.hasLearning},
        sortOrder: ReadingNoteSortOrder.titleAsc,
      ));
      await tester.pumpWidget(_wrap(ReadingNoteSearchScreen(
        notesOverride: _notes,
        queryPreferences: store,
      )));
      await tester.pumpAndSettle();

      expect(store.loadCount, 1);
      expect(_fieldText(tester), '坊っちゃん');
      expect(find.text('書名順'), findsOneWidget);
      expect(find.text('1件'), findsOneWidget);
    });

    testWidgets('並び順の変更で即 save される', (tester) async {
      _pumpLarge(tester);
      final store = _FakeStore(initial: const ReadingNoteQuery());
      await tester.pumpWidget(_wrap(ReadingNoteSearchScreen(
        notesOverride: _notes,
        queryPreferences: store,
      )));
      await tester.pumpAndSettle();
      expect(store.saved, isEmpty);

      await tester.tap(find.byKey(AppKeys.readingNoteSortMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('学びが多い順').last);
      await tester.pumpAndSettle();

      expect(
          store.saved.last.sortOrder, ReadingNoteSortOrder.learningCountDesc);
    });

    testWidgets('内容フィルタ変更で即 save される', (tester) async {
      _pumpLarge(tester);
      final store = _FakeStore(initial: const ReadingNoteQuery());
      await tester.pumpWidget(_wrap(ReadingNoteSearchScreen(
        notesOverride: _notes,
        queryPreferences: store,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, '行動あり'));
      await tester.pumpAndSettle();

      expect(store.saved.last.contentFilters,
          {ReadingNoteContentFilter.hasAction});
    });

    testWidgets('入力中は save せず、dispose 時に text を保存する', (tester) async {
      _pumpLarge(tester);
      final store = _FakeStore(initial: const ReadingNoteQuery());
      await tester.pumpWidget(_wrap(ReadingNoteSearchScreen(
        notesOverride: _notes,
        queryPreferences: store,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.readingNoteSearchField), '正義');
      await tester.pumpAndSettle();
      expect(store.saved, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(store.saved.last.text, '正義');
    });

    testWidgets('確定（onSubmitted）で text を保存する', (tester) async {
      _pumpLarge(tester);
      final store = _FakeStore(initial: const ReadingNoteQuery());
      await tester.pumpWidget(_wrap(ReadingNoteSearchScreen(
        notesOverride: _notes,
        queryPreferences: store,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.readingNoteSearchField), '主観');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(store.saved, isNotEmpty);
      expect(store.saved.last.text, '主観');
    });

    testWidgets('ロード完了前のユーザー入力を上書きしない', (tester) async {
      _pumpLarge(tester);
      final completer = Completer<ReadingNoteQuery?>();
      final store = _FakeStore(loadFuture: completer.future);
      await tester.pumpWidget(_wrap(ReadingNoteSearchScreen(
        notesOverride: _notes,
        queryPreferences: store,
      )));
      await tester.pump();

      await tester.enterText(find.byKey(AppKeys.readingNoteSearchField), '坊');
      await tester.pump();

      completer.complete(
          const ReadingNoteQuery(text: '保存済み', bookTitles: {'坊っちゃん'}));
      await tester.pumpAndSettle();

      expect(_fieldText(tester), '坊');
      expect(find.text('2件'), findsOneWidget);
      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      expect(chips.every((c) => !c.selected), isTrue,
          reason: '復元された書名絞り込みを適用してはならない');
    });

    testWidgets('store 未注入なら永続化せず例外も出ない（既存挙動のまま）', (tester) async {
      _pumpLarge(tester);
      await tester.pumpWidget(_wrap(ReadingNoteSearchScreen(
        notesOverride: _notes,
      )));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(AppKeys.readingNoteSearchField), '坊っちゃん');
      await tester.pumpAndSettle();
      expect(find.text('2件'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
