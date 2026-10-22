// コード適応神書 原則③（Semantics体系）— 読書キュー画面の試練
//
// 一覧 identifier は ListView.builder の外側で1回だけ発行し、
// 行 identifier は行idを含む一意な文字列になっていることを検証する
// （同一 identifier の重複発行は uiautomator/TalkBack の一意特定を壊す）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_provider.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_repository.dart';
import 'package:tsundoku_quest/features/reading_queue/presentation/reading_queue_screen.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

Book _book(String id, String title) => Book(
      id: id,
      title: title,
      source: BookSource.manual,
      createdAt: '2026-09-21T00:00:00Z',
    );

UserBook _ub(
  String id,
  String title, {
  BookStatus status = BookStatus.tsundoku,
}) =>
    UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      book: _book('b-$id', title),
      status: status,
      medium: BookMedium.physical,
      createdAt: '2026-09-21T00:00:00Z',
    );

ReadingQueueEntry _e(String id, int pos) => ReadingQueueEntry(
      userBookId: id,
      position: pos,
      addedAt: DateTime(2026, 9, 21),
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<ReadingQueueEntry> entries,
  required List<UserBook> userBooks,
}) async {
  final repo = InMemoryReadingQueueRepository();
  await repo.saveEntries(entries);

  final container = ProviderContainer(
    overrides: [
      readingQueueRepositoryProvider.overrideWithValue(repo),
      bookDataProvider.overrideWith((ref) => BookDataNotifier()),
    ],
  );
  final notifier = container.read(bookDataProvider.notifier);
  for (final ub in userBooks) {
    notifier.addUserBook(ub);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ReadingQueueScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('「次に読む一冊」カードと FAB に identifier が付与される', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      entries: [_e('ub-1', 1), _e('ub-2', 2)],
      userBooks: [_ub('ub-1', 'ドラゴン入門'), _ub('ub-2', '精霊の森')],
    );

    expect(
        find.bySemanticsIdentifier('btn_reading_queue_next_start'), findsOneWidget);
    expect(
        find.bySemanticsIdentifier('btn_reading_queue_add'), findsOneWidget);

    final next = find.bySemanticsIdentifier('btn_reading_queue_next_start');
    expect(tester.getSemantics(next).label, contains('次に読む一冊'));

    handle.dispose();
  });

  testWidgets('一覧 identifier は外側で1回だけ発行される（重複しない）', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      entries: [_e('ub-1', 1), _e('ub-2', 2), _e('ub-3', 3)],
      userBooks: [
        _ub('ub-1', '一冊目'),
        _ub('ub-2', '二冊目'),
        _ub('ub-3', '三冊目'),
      ],
    );

    // 一覧 identifier は1つだけ
    expect(find.bySemanticsIdentifier('list_reading_queue'), findsOneWidget);

    // 行 identifier は行idを含み、一意である
    expect(find.bySemanticsIdentifier('reading_queue_row_ub-2'), findsOneWidget);
    expect(find.bySemanticsIdentifier('reading_queue_row_ub-3'), findsOneWidget);
    // 先頭の ub-1 は「次に読む一冊」に昇格するため待ち行には現れない
    expect(find.bySemanticsIdentifier('reading_queue_row_ub-1'), findsNothing);
    // 行の identifier が一覧側へ重複発行されていない
    expect(find.bySemanticsIdentifier('list_reading_queue'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('既存の AppKeys / ValueKey は残存する（既存試練を壊していない）', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      entries: [_e('ub-1', 1), _e('ub-2', 2)],
      userBooks: [_ub('ub-1', '一冊目'), _ub('ub-2', '二冊目')],
    );

    expect(find.byKey(AppKeys.readingQueueScreen), findsOneWidget);
    expect(find.byKey(AppKeys.readingQueueNextCard), findsOneWidget);
    expect(find.byKey(AppKeys.readingQueueStartFromCard), findsOneWidget);
    expect(find.byKey(AppKeys.readingQueueList), findsOneWidget);
    expect(find.byKey(AppKeys.readingQueueAddButton), findsOneWidget);
    expect(find.byKey(const ValueKey('reading_queue_item_ub-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('reading_queue_up_ub-2')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('reading_queue_remove_ub-2')), findsOneWidget);

    handle.dispose();
  });

  testWidgets('空キューでは空状態の identifier が付与される', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, entries: const [], userBooks: const []);

    expect(
        find.bySemanticsIdentifier('txt_reading_queue_empty'), findsOneWidget);
    expect(find.byKey(AppKeys.readingQueueEmpty), findsOneWidget);

    handle.dispose();
  });
}
