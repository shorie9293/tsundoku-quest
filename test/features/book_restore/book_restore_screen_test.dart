import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/repositories/shelf_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/book_deletion_service.dart';
import 'package:tsundoku_quest/features/bookshelf/data/book_restore_service.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/book_restore_plan.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:tsundoku_quest/features/bookshelf/presentation/widgets/book_card.dart';
import 'package:tsundoku_quest/features/reading/data/quick_memo_draft_store.dart';
import 'package:tsundoku_quest/features/reading/domain/quick_memo.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_repository.dart';
import 'package:tsundoku_quest/features/shelves/data/shelf_controller.dart';
import 'package:tsundoku_quest/features/undo/presentation/undo_snack_bar.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

UserBook _userBook(String id) => UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      book: Book(
        id: 'book-$id',
        title: 'テスト本 $id',
        authors: const ['著者'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      ),
      status: BookStatus.tsundoku,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

Finder _card(String id) =>
    find.byWidgetPredicate((w) => w is BookCard && w.book.id == id);

Future<void> _revealBooks(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
}

class _FakeDraftStore implements QuickMemoDraftStore {
  final Map<String, QuickMemoDraft> drafts = {};

  @override
  Future<void> clear(String userBookId) async => drafts.remove(userBookId);

  @override
  Future<QuickMemoDraft?> load(String userBookId) async => drafts[userBookId];

  @override
  Future<void> save(String userBookId, QuickMemoDraft draft) async {
    drafts[userBookId] = draft;
  }
}

Widget _app(BookDataNotifier notifier, ShelfController shelves) =>
    ProviderScope(
      overrides: [
        bookDataProvider.overrideWith((ref) => notifier),
        shelfControllerProvider.overrideWith((ref) => shelves),
      ],
      child: const MaterialApp(home: BookshelfScreen()),
    );

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('hive_restore_ui_').path);
  });
  tearDownAll(() async {
    await Hive.close();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('単体削除の Undo で本体と子データが戻る（逆順復元）', (tester) async {
    final sessions = <ReadingSession>[
      const ReadingSession(
        id: 's-1',
        userBookId: 'ub-1',
        startedAt: '2026-02-01T10:00:00Z',
        endedAt: '2026-02-01T10:30:00Z',
        startPage: 1,
        endPage: 30,
        durationMinutes: 30,
        createdAt: '2026-02-01T10:30:00Z',
      ),
    ];
    final shelfRepo = InMemoryShelfRepository();
    final shelf = await shelfRepo.createShelf('冒険の棚');
    await shelfRepo.addBookToShelf(shelf.id, 'ub-1');
    final queueRepo = InMemoryReadingQueueRepository();
    await queueRepo.saveEntries([
      ReadingQueueEntry(
        userBookId: 'ub-1',
        position: 1,
        addedAt: DateTime.utc(2026, 2, 1),
      ),
    ]);
    final draftStore = _FakeDraftStore()
      ..drafts['ub-1'] =
          QuickMemoDraft(body: '下書き', updatedAt: DateTime.utc(2026, 2, 1));

    final observed = <BookRestoreStep>[];
    late final BookDataNotifier notifier;
    final deletionService = BookDeletionService(
      loadSessions: (id) async =>
          sessions.where((s) => s.userBookId == id).toList(),
      deleteSession: (id) async => sessions.removeWhere((s) => s.id == id),
      loadShelves: shelfRepo.listShelves,
      removeBookFromShelf: shelfRepo.removeBookFromShelf,
      loadQueue: queueRepo.loadEntries,
      saveQueue: queueRepo.saveEntries,
      draftStore: draftStore,
    );
    final restoreService = BookRestoreService(
      loadSessions: (id) async =>
          sessions.where((s) => s.userBookId == id).toList(),
      loadShelves: shelfRepo.listShelves,
      loadQueue: queueRepo.loadEntries,
      draftStore: draftStore,
      addUserBook: (ub) => notifier.addUserBook(ub),
      addSession: (s) async => sessions.add(s),
      addBookToShelf: shelfRepo.addBookToShelf,
      restoreQueueEntries: (entries) async {
        final current = await queueRepo.loadEntries();
        final target = {for (final e in entries) e.userBookId};
        await queueRepo.saveEntries([
          ...current.where((e) => !target.contains(e.userBookId)),
          ...entries,
        ]);
      },
      saveDraft: draftStore.save,
      onStep: observed.add,
    );
    notifier = BookDataNotifier(
      null,
      null,
      null,
      null,
      null,
      deletionService,
      restoreService,
    )..addUserBook(_userBook('ub-1'));

    await tester.pumpWidget(
      _app(notifier, ShelfController(InMemoryShelfRepository())),
    );
    await _revealBooks(tester);

    // スワイプ削除 → 確認
    await tester.drag(_card('ub-1'), const Offset(-900, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));

    expect(notifier.state.userBooks, isEmpty);
    // 連鎖削除が走っている
    expect(sessions, isEmpty);
    expect(draftStore.drafts.containsKey('ub-1'), isFalse);

    // Undo
    await tester.tap(find.byKey(undoActionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 本体と子が両方戻る
    expect(notifier.state.userBooks.map((b) => b.id), ['ub-1']);
    expect(sessions.map((s) => s.id), ['s-1']);
    expect(
        (await shelfRepo.listShelves()).single.userBookIds, contains('ub-1'));
    expect(
      (await queueRepo.loadEntries()).map((e) => e.userBookId),
      contains('ub-1'),
    );
    expect(draftStore.drafts['ub-1']?.body, '下書き');
    // 逆順（本体→trophies→…→sessions）で走っている
    expect(observed.first, BookRestoreStep.book);
    expect(observed.last, BookRestoreStep.sessions);
  });

  testWidgets('復元結果は1回だけ SnackBar で通知される（UI は止まらない）', (tester) async {
    late final BookDataNotifier notifier;
    final restoreService = BookRestoreService(
      addUserBook: (ub) => notifier.addUserBook(ub),
    );
    notifier = BookDataNotifier(
      null,
      null,
      null,
      null,
      null,
      null,
      restoreService,
    )..addUserBook(_userBook('ub-1'));

    await tester.pumpWidget(
      _app(notifier, ShelfController(InMemoryShelfRepository())),
    );
    await _revealBooks(tester);

    await tester.drag(_card('ub-1'), const Offset(-900, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(notifier.state.userBooks, isEmpty);

    await tester.tap(find.byKey(undoActionKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(notifier.state.userBooks.map((b) => b.id), ['ub-1']);
    expect(find.textContaining('件を復元しました'), findsOneWidget);
  });
}
