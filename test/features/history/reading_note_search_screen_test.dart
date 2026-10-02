import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/features/history/data/reading_notes_provider.dart';
import 'package:tsundoku_quest/features/history/domain/reading_note_query.dart';
import 'package:tsundoku_quest/features/history/presentation/reading_note_search_screen.dart';

ReadingNoteItem _note(
  String id, {
  String? bookTitle,
  List<String> learnings = const [],
  String action = '',
  String? favoriteQuote,
  String createdAt = '2026-01-01T00:00:00Z',
}) {
  return ReadingNoteItem(
    id: id,
    userBookId: 'ub_$id',
    bookTitle: bookTitle,
    learnings: learnings,
    action: action,
    favoriteQuote: favoriteQuote,
    createdAt: createdAt,
  );
}

Widget _harness(List<ReadingNoteItem> notes) {
  return ProviderScope(
    child: MaterialApp(
      home: ReadingNoteSearchScreen(notesOverride: notes),
    ),
  );
}

final _baseNotes = [
  _note('n1',
      bookTitle: '吾輩は猫である',
      learnings: ['主観は移ろいやすい'],
      action: '自分の視点を疑ってみる',
      favoriteQuote: '太平の眠りを覚ます',
      createdAt: '2026-03-01T10:00:00Z'),
  _note('n2',
      bookTitle: '坊っちゃん',
      learnings: ['正義感は美しい'],
      action: '',
      favoriteQuote: null,
      createdAt: '2026-02-01T10:00:00Z'),
  _note('n3',
      bookTitle: '吾輩は猫である',
      learnings: [],
      action: '怒りを持ち続ける',
      favoriteQuote: '泄尿がごとし',
      createdAt: '2026-01-01T10:00:00Z'),
  _note('n4', bookTitle: null, learnings: [], action: '', favoriteQuote: null),
];

Future<void> _pump(WidgetTester tester, List<ReadingNoteItem> notes) async {
  await tester.pumpWidget(_harness(notes));
  await tester.pump();
}

void main() {
  group('ReadingNoteSearchScreen', () {
    testWidgets('初期表示で全件が表示される', (tester) async {
      await _pump(tester, _baseNotes);
      expect(find.byKey(AppKeys.readingNoteList), findsOneWidget);
      expect(find.byKey(const Key('card_reading_note_n1')), findsOneWidget);
      expect(find.byKey(const Key('card_reading_note_n2')), findsOneWidget);
      expect(find.byKey(AppKeys.readingNoteResultLabel), findsOneWidget);
      expect(find.text('4件'), findsOneWidget);
    });

    testWidgets('検索文字（学び）で絞り込める', (tester) async {
      await _pump(tester, _baseNotes);
      await tester.enterText(
          find.byKey(AppKeys.readingNoteSearchField), '正義感');
      await tester.pump();
      expect(find.byKey(const Key('card_reading_note_n2')), findsOneWidget);
      expect(find.byKey(const Key('card_reading_note_n1')), findsNothing);
      expect(find.text('1件'), findsOneWidget);
    });

    testWidgets('検索文字（書籍名）で絞り込める', (tester) async {
      await _pump(tester, _baseNotes);
      await tester.enterText(
          find.byKey(AppKeys.readingNoteSearchField), '猫');
      await tester.pump();
      expect(find.byKey(const Key('card_reading_note_n1')), findsOneWidget);
      expect(find.byKey(const Key('card_reading_note_n3')), findsOneWidget);
      expect(find.text('2件'), findsOneWidget);
    });

    testWidgets('検索文字（action）で絞り込める', (tester) async {
      await _pump(tester, _baseNotes);
      await tester.enterText(
          find.byKey(AppKeys.readingNoteSearchField), '怒り');
      await tester.pump();
      expect(find.byKey(const Key('card_reading_note_n3')), findsOneWidget);
      expect(find.byKey(const Key('card_reading_note_n1')), findsNothing);
    });

    testWidgets('検索文字（引用）で絞り込める', (tester) async {
      await _pump(tester, _baseNotes);
      await tester.enterText(
          find.byKey(AppKeys.readingNoteSearchField), '太平の眠り');
      await tester.pump();
      expect(find.byKey(const Key('card_reading_note_n1')), findsOneWidget);
      expect(find.text('1件'), findsOneWidget);
    });

    testWidgets('クリアで全件に復帰する', (tester) async {
      await _pump(tester, _baseNotes);
      await tester.enterText(
          find.byKey(AppKeys.readingNoteSearchField), '正義感');
      await tester.pump();
      expect(find.byKey(const Key('card_reading_note_n1')), findsNothing);
      await tester.tap(find.byKey(AppKeys.readingNoteSearchClear));
      await tester.pump();
      expect(find.text('4件'), findsOneWidget);
      expect(find.byKey(const Key('card_reading_note_n1')), findsOneWidget);
    });

    testWidgets('ソートメニューで並び替え・表示ラベルが変わる', (tester) async {
      await _pump(tester, _baseNotes);
      await tester.tap(find.byKey(AppKeys.readingNoteSortMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('書名順').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('card_reading_note_n2')), findsOneWidget);
      expect(find.text('書名順'), findsOneWidget);
      // 書名順: 吾輩は猫である(n1) → 坊っちゃん(n2)
      final n1Center =
          tester.getCenter(find.byKey(const Key('card_reading_note_n1')));
      final n2Center =
          tester.getCenter(find.byKey(const Key('card_reading_note_n2')));
      expect(n2Center.dy, greaterThan(n1Center.dy));

      await tester.tap(find.byKey(AppKeys.readingNoteSortMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('古い順').last);
      await tester.pumpAndSettle();
      expect(find.text('古い順'), findsOneWidget);
      // 古い順: n3(1月) → n2(2月)
      final n3Center =
          tester.getCenter(find.byKey(const Key('card_reading_note_n3')));
      final n2OldestCenter =
          tester.getCenter(find.byKey(const Key('card_reading_note_n2')));
      expect(n3Center.dy, lessThan(n2OldestCenter.dy));
    });

    testWidgets('書籍 FilterChip 選択で絞り込み・再タップで解除', (tester) async {
      await _pump(tester, _baseNotes);
      await tester.tap(find.widgetWithText(FilterChip, '吾輩は猫である'));
      await tester.pump();
      expect(find.byKey(const Key('card_reading_note_n1')), findsOneWidget);
      expect(find.byKey(const Key('card_reading_note_n2')), findsNothing);
      expect(find.text('2件'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, '吾輩は猫である'));
      await tester.pump();
      expect(find.text('4件'), findsOneWidget);
    });

    testWidgets('内容 FilterChip で絞り込める', (tester) async {
      await _pump(tester, _baseNotes);
      await tester.tap(find.widgetWithText(FilterChip, '学びあり'));
      await tester.pump();
      expect(find.byKey(const Key('card_reading_note_n4')), findsNothing);
      expect(find.text('2件'), findsOneWidget);
    });

    testWidgets('複数内容フィルタは AND で絞り込める', (tester) async {
      await _pump(tester, _baseNotes);
      await tester.tap(find.widgetWithText(FilterChip, '学びあり'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, '行動あり'));
      await tester.pump();
      expect(find.byKey(const Key('card_reading_note_n1')), findsOneWidget);
      expect(find.byKey(const Key('card_reading_note_n2')), findsNothing);
      expect(find.byKey(const Key('card_reading_note_n3')), findsNothing);
      expect(find.text('1件'), findsOneWidget);
    });

    testWidgets('リセットで条件が初期化される', (tester) async {
      await _pump(tester, _baseNotes);
      await tester.enterText(
          find.byKey(AppKeys.readingNoteSearchField), '正義感');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, '学びあり'));
      await tester.pump();
      expect(find.text('1件'), findsOneWidget);
      await tester.tap(find.byKey(AppKeys.readingNoteReset));
      await tester.pump();
      expect(find.text('4件'), findsOneWidget);
      expect(find.byKey(const Key('card_reading_note_n1')), findsOneWidget);
      expect(find.byKey(const Key('card_reading_note_n2')), findsOneWidget);
    });

    testWidgets('リセットは isDefault のとき無効', (tester) async {
      await _pump(tester, _baseNotes);
      final button = tester.widget<TextButton>(
        find.byKey(AppKeys.readingNoteReset),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('結果0件で空状態を表示する', (tester) async {
      await _pump(tester, _baseNotes);
      await tester.enterText(
          find.byKey(AppKeys.readingNoteSearchField), '存在しない言葉xyz');
      await tester.pump();
      expect(find.byKey(AppKeys.readingNoteEmpty), findsOneWidget);
      expect(find.text('条件に合う感想がありません'), findsOneWidget);
      expect(find.byKey(AppKeys.readingNoteList), findsNothing);
    });

    testWidgets('ソートとフィルタの組合せでも件数ラベルが一致する', (tester) async {
      await _pump(tester, _baseNotes);
      await tester.enterText(
          find.byKey(AppKeys.readingNoteSearchField), '猫');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, '引用あり'));
      await tester.pump();
      expect(find.byKey(AppKeys.readingNoteResultLabel), findsOneWidget);
      expect(find.text('2件'), findsOneWidget);
    });
  });

  group('ReadingNoteQueryService（画面経由の妥当性確認）', () {
    test('resultLabel が正しい形式', () {
      expect(ReadingNoteQueryService.resultLabel(3), '3件');
    });
  });
}
