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

Book _book(String id, String title) => Book(
      id: id,
      title: title,
      source: BookSource.manual,
      createdAt: '2026-09-21T00:00:00Z',
    );

UserBook _ub(
  String id,
  String title, {
  String? bookId,
  String? bookTitleId,
}) =>
    UserBook(
      id: id,
      userId: 'user-1',
      // userBookId と bookId は意図的に別値にできる
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

/// 遷移先の読書画面の代役。受け取ったクエリ id と現在地を表示するだけのプローブ。
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

/// Hive を開かない（InMemory + overrides）。遷移確認のため自前 GoRouter を組む。
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
  // controller の load() 完了を待つ
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

/// 遷移先プローブが表示している現在地（クエリ付き）
String _probeUri(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('reading_probe_uri'))).data ?? '';

void main() {
  testWidgets('「次に読む一冊」カードを tap すると /reading へ userBookId 付きで遷移する',
      (tester) async {
    await _pump(
      tester,
      entries: [_e('ub-1', 1), _e('ub-2', 2)],
      userBooks: [_ub('ub-1', 'ドラゴン入門'), _ub('ub-2', '精霊の森')],
    );

    await tester.tap(find.byKey(AppKeys.readingQueueStartFromCard));
    await tester.pumpAndSettle();

    expect(_probeUri(tester), startsWith('/reading'));
    expect(
      tester.widget<Text>(find.byKey(const Key('reading_probe_id'))).data,
      'ub-1',
    );
  });

  testWidgets('待ち行（rest の先頭）を tap しても /reading へ userBookId 付きで遷移する',
      (tester) async {
    await _pump(
      tester,
      entries: [_e('ub-1', 1), _e('ub-2', 2), _e('ub-3', 3)],
      userBooks: [
        _ub('ub-1', '一冊目'),
        _ub('ub-2', '二冊目'),
        _ub('ub-3', '三冊目'),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('reading_queue_start_ub-2')));
    await tester.pumpAndSettle();

    expect(_probeUri(tester), startsWith('/reading'));
    expect(
      tester.widget<Text>(find.byKey(const Key('reading_probe_id'))).data,
      'ub-2',
    );
  });

  testWidgets('キューが空の時はカード導線が存在しない', (tester) async {
    await _pump(tester, entries: const [], userBooks: const []);

    expect(find.byKey(AppKeys.readingQueueStartFromCard), findsNothing);
    expect(find.text('待ちの本はまだ無い'), findsOneWidget);
    expect(find.byKey(const Key('reading_probe_uri')), findsNothing);
  });

  testWidgets('行の並び替えボタン tap では読書画面へ遷移しない', (tester) async {
    await _pump(
      tester,
      entries: [_e('ub-1', 1), _e('ub-2', 2)],
      userBooks: [_ub('ub-1', '一冊目'), _ub('ub-2', '二冊目')],
    );

    await tester.tap(find.byKey(const ValueKey('reading_queue_up_ub-2')));
    await tester.pumpAndSettle();

    // 遷移していない（行タップ導線に吸収されていない）
    expect(find.byKey(const Key('reading_probe_uri')), findsNothing);
    expect(find.byKey(AppKeys.readingQueueScreen), findsOneWidget);
    // 並び替え自体は従来通り効いている（ub-2 が先頭へ繰り上がる）
    expect(
      find.descendant(
        of: find.byKey(AppKeys.readingQueueNextCard),
        matching: find.text('二冊目'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('遷移に渡る id は bookId ではなく userBookId である', (tester) async {
    await _pump(
      tester,
      entries: [_e('ub-7', 1)],
      userBooks: [
        _ub(
          'ub-7',
          '取り違え検証本',
          bookId: 'book-xyz', // ub.bookId
          bookTitleId: 'b-abc', // ub.book.id
        ),
      ],
    );

    await tester.tap(find.byKey(AppKeys.readingQueueStartFromCard));
    await tester.pumpAndSettle();

    expect(_probeUri(tester), startsWith('/reading'));
    expect(_probeUri(tester), contains('id=ub-7'));
    final passed =
        tester.widget<Text>(find.byKey(const Key('reading_probe_id'))).data;
    expect(passed, 'ub-7');
    expect(passed, isNot('book-xyz'));
    expect(passed, isNot('b-abc'));
  });
}
