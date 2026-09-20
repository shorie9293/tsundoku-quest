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

/// Hive を一切開かない（InMemory + overrides）。pumpAndSettle ではなく pump で進める。

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
  // controller の load() 完了を待つ（モック時間の FakeAsync を進める）
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('空キューでは空状態メッセージを出す', (tester) async {
    await _pump(tester, entries: const [], userBooks: const []);

    expect(find.byKey(AppKeys.readingQueueScreen), findsOneWidget);
    expect(find.byKey(AppKeys.readingQueueEmpty), findsOneWidget);
    expect(find.byKey(AppKeys.readingQueueNextCard), findsNothing);
  });

  testWidgets('「次に読む一冊」カードに先頭の本を出す', (tester) async {
    await _pump(
      tester,
      entries: [_e('ub-1', 1), _e('ub-2', 2)],
      userBooks: [_ub('ub-1', 'ドラゴン入門'), _ub('ub-2', '精霊の森')],
    );

    expect(find.byKey(AppKeys.readingQueueNextCard), findsOneWidget);
    expect(find.text('ドラゴン入門'), findsOneWidget);
    expect(find.text('精霊の森'), findsOneWidget);
  });

  testWidgets('上下移動ボタンで順序が入れ替わる', (tester) async {
    await _pump(
      tester,
      entries: [_e('ub-1', 1), _e('ub-2', 2), _e('ub-3', 3)],
      userBooks: [
        _ub('ub-1', '一冊目'),
        _ub('ub-2', '二冊目'),
        _ub('ub-3', '三冊目'),
      ],
    );

    // 待ち行頭 ub-2 を1つ前へ → キュー全体が [ub-2, ub-1, ub-3] になる
    await tester.tap(find.byKey(const ValueKey('reading_queue_up_ub-2')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // キュー先頭が ub-2 へ繰り上がるため「次に読む一冊」も ub-2 になる
    expect(find.byKey(AppKeys.readingQueueNextCard), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(AppKeys.readingQueueNextCard),
              matching: find.text('二冊目'),
            ),
          )
          .data,
      '二冊目',
    );

    // 待ち行は ub-1 → ub-3 の順（ub-1 が上）
    final firstTile = find.byKey(const ValueKey('reading_queue_item_ub-1'));
    final secondTile = find.byKey(const ValueKey('reading_queue_item_ub-3'));
    expect(firstTile, findsOneWidget);
    expect(secondTile, findsOneWidget);
    final rectFirst = tester.getRect(firstTile);
    final rectSecond = tester.getRect(secondTile);
    expect(rectFirst.top, lessThan(rectSecond.top));
  });

  testWidgets('削除ボタンで行が消える', (tester) async {
    await _pump(
      tester,
      entries: [_e('ub-1', 1), _e('ub-2', 2)],
      userBooks: [_ub('ub-1', '一冊目'), _ub('ub-2', '二冊目')],
    );

    expect(
      find.byKey(const ValueKey('reading_queue_item_ub-2')),
      findsOneWidget,
    );
    await tester
        .tap(find.byKey(const ValueKey('reading_queue_remove_ub-2')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const ValueKey('reading_queue_item_ub-2')),
      findsNothing,
    );
  });

  testWidgets('FAB から積読をキューに追加できる', (tester) async {
    await _pump(tester, entries: const [], userBooks: [_ub('ub-1', '一冊目')]);

    await tester.tap(find.byKey(AppKeys.readingQueueAddButton));
    // ボトムシートの出現アニメーションを完了させる
    // （50ms の pump では ListTile が画面外の高さに留まり tap が空振りする）
    await tester.pumpAndSettle();

    expect(find.text('積読から追加する'), findsOneWidget);
    await tester.tap(find.text('一冊目'));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.readingQueueNextCard), findsOneWidget);
    expect(find.text('一冊目'), findsOneWidget);
  });
}
