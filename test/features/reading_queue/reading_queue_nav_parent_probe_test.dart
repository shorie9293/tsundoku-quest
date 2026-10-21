import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tsundoku_quest/core/testing/widget_keys.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_provider.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_repository.dart';
import 'package:tsundoku_quest/features/reading_queue/presentation/reading_queue_screen.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

/// 親探針（イシコリドメが合成の不変条件を撃つための試練）。
///
/// 「次に読む一冊」カードの遷移先は *キューの現在の先頭* でなければならない。
/// 並び替えで先頭が入れ替わった後も、カードタップが新しい先頭の userBookId を
/// 渡すことを固定する（カードが古い選択を握り続ける型の禍津を撃つ）。

Book _book(String id, String title) => Book(
      id: id,
      title: title,
      source: BookSource.manual,
      createdAt: '2026-09-21T00:00:00Z',
    );

UserBook _ub(String id, String title, {String? bookId, String? bookTitleId}) =>
    UserBook(
      id: id,
      userId: 'user-1',
      bookId: bookId ?? 'book-$id',
      book: _book(bookTitleId ?? 'b-$id', title),
      status: BookStatus.tsundoku,
      medium: BookMedium.physical,
      createdAt: '2026-09-21T00:00:00Z',
    );

ReadingQueueEntry _e(String id, int pos) => ReadingQueueEntry(
      userBookId: id,
      position: pos,
      addedAt: DateTime(2026, 9, 21),
    );

class _ReadingProbe extends StatelessWidget {
  const _ReadingProbe({required this.id});

  final String? id;

  @override
  Widget build(BuildContext context) {
    final state = GoRouterState.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(id ?? '(id なし)', key: const Key('reading_probe_id')),
            Text(state.uri.toString(), key: const Key('reading_probe_uri')),
          ],
        ),
      ),
    );
  }
}

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

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ReadingQueueScreen(),
      ),
      GoRoute(
        path: '/reading',
        builder: (context, state) =>
            _ReadingProbe(id: state.uri.queryParameters['id']),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

String? _probeId(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('reading_probe_id'))).data;

void main() {
  testWidgets('並び替えで先頭が変わった後、カード tap は新しい先頭の userBookId を渡す',
      (tester) async {
    await _pump(
      tester,
      entries: [_e('ub-1', 1), _e('ub-2', 2)],
      userBooks: [_ub('ub-1', '一冊目'), _ub('ub-2', '二冊目')],
    );

    // 待ち行の先頭（ub-2）を「前へ」で繰り上げる＝カードの対象が ub-2 へ変わる
    await tester.tap(find.byKey(const ValueKey('reading_queue_up_ub-2')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.descendant(
        of: find.byKey(AppKeys.readingQueueNextCard),
        matching: find.text('二冊目'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(AppKeys.readingQueueStartFromCard));
    await tester.pumpAndSettle();

    expect(_probeId(tester), 'ub-2');
  });

  testWidgets('削除ボタン tap では遷移せず、行だけが消える', (tester) async {
    await _pump(
      tester,
      entries: [_e('ub-1', 1), _e('ub-2', 2), _e('ub-3', 3)],
      userBooks: [
        _ub('ub-1', '一冊目'),
        _ub('ub-2', '二冊目'),
        _ub('ub-3', '三冊目'),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('reading_queue_remove_ub-2')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('reading_probe_uri')), findsNothing);
    expect(find.byKey(const ValueKey('reading_queue_item_ub-2')), findsNothing);
    expect(find.byKey(const ValueKey('reading_queue_item_ub-3')), findsOneWidget);
  });

  testWidgets('キューが1冊だけの時もカード導線が機能する', (tester) async {
    await _pump(
      tester,
      entries: [_e('solo-1', 1)],
      userBooks: [_ub('solo-1', '唯一の本')],
    );

    await tester.tap(find.byKey(AppKeys.readingQueueStartFromCard));
    await tester.pumpAndSettle();

    expect(_probeId(tester), 'solo-1');
  });
}
