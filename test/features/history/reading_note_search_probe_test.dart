import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/history/data/reading_notes_provider.dart';
import 'package:tsundoku_quest/features/history/domain/reading_note_query.dart';
import 'package:tsundoku_quest/features/history/presentation/reading_note_search_screen.dart';

/// 親探針: 合成の不変条件を撃つ（眷属は個別操作しか撃ちがち）
ReadingNoteItem _n(
  String id, {
  String? title,
  List<String> learnings = const [],
  String action = '',
  String? quote,
  String createdAt = '2026-09-01T00:00:00Z',
}) =>
    ReadingNoteItem(
      id: id,
      userBookId: 'ub-$id',
      bookTitle: title,
      learnings: learnings,
      action: action,
      favoriteQuote: quote,
      createdAt: createdAt,
    );

void main() {
  group('親探針: 読書感想検索の合成不変条件', () {
    test('ソートは絞込後の部分集合に適用される（母集合全体の最大値が先頭に来ない）', () {
      final notes = [
        _n('a', title: 'A', learnings: const ['x', 'y', 'z']),
        _n('b', title: 'B', learnings: const ['x']),
        _n('c', title: 'C', learnings: const ['x', 'y']),
      ];
      // C を選ぶと母集合の最大 learningCount(=3 の A) は対象外
      final q = const ReadingNoteQuery()
          .copyWith(bookTitles: {'C'}, sortOrder: ReadingNoteSortOrder.learningCountDesc);
      final result = ReadingNoteQueryService.apply(notes, q);
      expect(result.map((e) => e.id).toList(), ['c']);
    });

    test('検索 × 書籍 × 内容 の AND 合成と件数一致', () {
      final notes = [
        _n('a', title: 'A', learnings: const ['勇気'], quote: 'q1'),
        _n('b', title: 'A', learnings: const ['勇気']),
        _n('c', title: 'B', learnings: const ['勇気'], quote: 'q2'),
      ];
      final q = const ReadingNoteQuery().copyWith(
        text: '勇気',
        bookTitles: {'A'},
        contentFilters: {ReadingNoteContentFilter.hasQuote},
      );
      final result = ReadingNoteQueryService.apply(notes, q);
      expect(result.map((e) => e.id).toList(), ['a']);
      expect(ReadingNoteQueryService.resultLabel(result.length), '1件');
    });

    test('内容フィルタ複数は AND（両方満たすもののみ）', () {
      final notes = [
        _n('a', learnings: const ['x'], action: 'do'),
        _n('b', learnings: const ['x']),
        _n('c', action: 'do'),
      ];
      final result = ReadingNoteQueryService.apply(
        notes,
        const ReadingNoteQuery().copyWith(contentFilters: {
          ReadingNoteContentFilter.hasLearning,
          ReadingNoteContentFilter.hasAction,
        }),
      );
      expect(result.map((e) => e.id).toList(), ['a']);
    });

    test('正規化名の全角書籍名でも絞り込める（表記ゆれ耐性）', () {
      final notes = [
        _n('a', title: '７つの習慣', learnings: const ['ABC']),
        _n('b', title: '７つの習慣', learnings: const ['xyz']),
      ];
      final result = ReadingNoteQueryService.apply(
        notes,
        const ReadingNoteQuery().copyWith(text: 'abc'),
      );
      expect(result.map((e) => e.id).toList(), ['a']);
    });
  });

  testWidgets('親探針: 画面の件数ラベルは3条件合成後の件数と一致する', (tester) async {
    final notes = [
      _n('a', title: 'A', learnings: const ['勇気'], quote: 'q1'),
      _n('b', title: 'A', learnings: const ['勇気']),
      _n('c', title: 'B', learnings: const ['勇気'], quote: 'q2'),
    ];
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ReadingNoteSearchScreen(notesOverride: notes),
      ),
    ));
    await tester.pump();

    await tester.enterText(
        find.byKey(AppKeys.readingNoteSearchField), '勇気');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'A'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, '引用あり'));
    await tester.pump();

    final label = tester
        .widget<Text>(find.byKey(AppKeys.readingNoteResultLabel))
        .data;
    expect(label, '1件');
  });
}
