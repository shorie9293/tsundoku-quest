import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/book_shelf.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/repositories/shelf_repository.dart';
import 'package:tsundoku_quest/features/bookshelf/data/book_deletion_service.dart';
import 'package:tsundoku_quest/features/bookshelf/data/book_restore_service.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/book_deletion_plan.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/book_restore_plan.dart';
import 'package:tsundoku_quest/features/reading/data/quick_memo_draft_store.dart';
import 'package:tsundoku_quest/features/reading/domain/quick_memo.dart';
import 'package:tsundoku_quest/features/reading_queue/data/reading_queue_repository.dart';

UserBook _userBook(String id) => UserBook(
      id: id,
      userId: 'user-1',
      bookId: 'book-$id',
      book: Book(
        id: 'book-$id',
        title: '本 $id',
        authors: const ['著者'],
        source: BookSource.manual,
        createdAt: '2026-01-01T00:00:00Z',
      ),
      status: BookStatus.tsundoku,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

ReadingSession _session(String id, String userBookId) => ReadingSession(
      id: id,
      userBookId: userBookId,
      startedAt: '2026-02-01T10:00:00Z',
      endedAt: '2026-02-01T10:30:00Z',
      startPage: 1,
      endPage: 30,
      durationMinutes: 30,
      createdAt: '2026-02-01T10:30:00Z',
    );

/// 削除→復元の往復に使うインメモリ環境。
class _Env {
  _Env(this.userBookId);

  final String userBookId;
  final List<ReadingSession> sessions = [];
  final Map<String, QuickMemoDraft> drafts = {};
  final InMemoryShelfRepository shelfRepo = InMemoryShelfRepository();
  final InMemoryReadingQueueRepository queueRepo =
      InMemoryReadingQueueRepository();
  List<BookShelf> shelves = [];

  // 偽の永続化（呼び出し観測用）
  final List<String> journal = [];

  Future<List<BookShelf>> loadShelves() async =>
      shelves = await shelfRepo.listShelves();

  Future<void> addSession(ReadingSession session) async {
    sessions.add(session);
    journal.add('session:${session.id}');
  }

  Future<void> addBookToShelf(String shelfId, String userBookId) async {
    await shelfRepo.addBookToShelf(shelfId, userBookId);
    journal.add('shelf:$shelfId');
  }

  Future<void> restoreQueueEntries(List<ReadingQueueEntry> entries) async {
    final current = await queueRepo.loadEntries();
    final target = {for (final e in entries) e.userBookId};
    await queueRepo.saveEntries([
      ...current.where((e) => !target.contains(e.userBookId)),
      ...entries,
    ]);
    journal.add('queue:${entries.length}');
  }

  Future<void> saveDraft(String userBookId, QuickMemoDraft draft) async {
    drafts[userBookId] = draft;
    journal.add('draft:$userBookId');
  }

  BookDeletionService deletionService() => BookDeletionService(
        loadSessions: (id) async =>
            sessions.where((s) => s.userBookId == id).toList(),
        deleteSession: (sessionId) async {
          sessions.removeWhere((s) => s.id == sessionId);
        },
        loadShelves: loadShelves,
        removeBookFromShelf: shelfRepo.removeBookFromShelf,
        loadQueue: queueRepo.loadEntries,
        saveQueue: queueRepo.saveEntries,
        draftStore: _MemoryDraftStore(drafts),
      );

  BookRestoreService restoreService({
    void Function(BookRestoreStep step)? onStep,
    bool failShelf = false,
  }) =>
      BookRestoreService(
        loadSessions: (id) async =>
            sessions.where((s) => s.userBookId == id).toList(),
        loadShelves: loadShelves,
        loadQueue: queueRepo.loadEntries,
        draftStore: _MemoryDraftStore(drafts),
        addUserBook: (_) => journal.add('book'),
        addSession: addSession,
        addBookToShelf: failShelf
            ? (shelfId, id) async => throw StateError('棚の復元に失敗')
            : addBookToShelf,
        restoreQueueEntries: restoreQueueEntries,
        saveDraft: saveDraft,
        onStep: onStep,
      );
}

class _MemoryDraftStore implements QuickMemoDraftStore {
  _MemoryDraftStore(this.drafts);

  final Map<String, QuickMemoDraft> drafts;

  @override
  Future<QuickMemoDraft?> load(String userBookId) async => drafts[userBookId];

  @override
  Future<void> save(String userBookId, QuickMemoDraft draft) async {
    drafts[userBookId] = draft;
  }

  @override
  Future<void> clear(String userBookId) async {
    drafts.remove(userBookId);
  }
}

/// 削除前の環境を作る（当該書＋巻き込まれてはいけない別の書）。
Future<void> _seed(_Env env) async {
  env.sessions.add(_session('s-1', env.userBookId));
  env.sessions.add(_session('s-2', env.userBookId));
  env.sessions.add(_session('s-other', 'ub-other'));
  final shelf = await env.shelfRepo.createShelf('冒険の棚');
  await env.shelfRepo.addBookToShelf(shelf.id, env.userBookId);
  await env.shelfRepo.addBookToShelf(shelf.id, 'ub-other');
  env.shelves = await env.shelfRepo.listShelves();
  await env.queueRepo.saveEntries([
    ReadingQueueEntry(
      userBookId: env.userBookId,
      position: 1,
      addedAt: DateTime.utc(2026, 2, 1),
    ),
    ReadingQueueEntry(
      userBookId: 'ub-other',
      position: 2,
      addedAt: DateTime.utc(2026, 2, 2),
    ),
  ]);
  env.drafts[env.userBookId] =
      QuickMemoDraft(body: '下書き本文', updatedAt: DateTime.utc(2026, 2, 1));
}

void main() {
  group('BookRestorePlan', () {
    test('子ステップは削除計画の厳密な逆順で固定される', () {
      final plan = BookRestorePlan.forBook('ub-1');
      expect(
        List.of(BookRestorePlan.childStepsInReverseDeletionOrder),
        BookDeletionStep.values.reversed
            .map((s) => BookRestorePlan.reverseOfDeletion[s])
            .toList(),
      );
      // 本体は先頭、以降は子の逆順
      expect(plan.steps, [
        BookRestoreStep.book,
        ...BookRestorePlan.childStepsInReverseDeletionOrder,
      ]);
    });

    test('空 id は ArgumentError', () {
      expect(() => BookRestorePlan.forBook('  '), throwsArgumentError);
    });

    test('スナップショットは空 id を拒否する', () {
      expect(
        () => BookRestoreSnapshot(userBook: _userBook('  ')),
        throwsArgumentError,
      );
      expect(
          () =>
              BookRestoreSnapshot(userBook: _userBook('ub-1'), shelfIds: ['']),
          throwsArgumentError);
    });
  });

  group('BookRestoreService', () {
    test('削除→Undo で本体と子データが両方戻り、他書は巻き込まない', () async {
      final env = _Env('ub-1');
      await _seed(env);
      final book = _userBook('ub-1');

      // 1. 削除前スナップショット
      final snapshot = await env.restoreService().capture(userBook: book);
      expect(snapshot.sessions.length, 2);
      expect(snapshot.shelfIds.length, 1);
      expect(snapshot.queueEntries.length, 1);
      expect(snapshot.quickMemoDraft, isNotNull);

      // 2. 連鎖削除
      await env.deletionService().run(BookDeletionPlan.forBook('ub-1'));
      expect(env.sessions.where((s) => s.userBookId == 'ub-1'), isEmpty);
      expect(env.drafts.containsKey('ub-1'), isFalse);
      final queueAfterDelete = await env.queueRepo.loadEntries();
      expect(queueAfterDelete.map((e) => e.userBookId), ['ub-other']);

      // 3. 逆順復元
      final report = await env
          .restoreService()
          .restore(BookRestorePlan.forBook('ub-1'), snapshot);

      expect(report.isClean, isTrue, reason: report.toString());
      // 本体1 + セッション2 + 棚1 + キュー1 + 下書き1
      expect(report.restoredCount, 6);

      expect(env.sessions.map((s) => s.id), containsAll(['s-1', 's-2']));
      // セッションの開始/終了/所要時間は保持されたまま戻る
      final restored = env.sessions.firstWhere((s) => s.id == 's-1');
      expect(restored.startedAt, '2026-02-01T10:00:00Z');
      expect(restored.endedAt, '2026-02-01T10:30:00Z');
      expect(restored.durationMinutes, 30);

      final shelves = await env.shelfRepo.listShelves();
      expect(shelves.single.userBookIds, containsAll(['ub-1', 'ub-other']));

      final queue = await env.queueRepo.loadEntries();
      expect(queue.map((e) => e.userBookId), containsAll(['ub-1', 'ub-other']));
      expect(env.drafts['ub-1']?.body, '下書き本文');
      expect(env.journal, contains('book'));
    });

    test('復元は削除の逆順（trophies→…→sessions）で実行される', () async {
      final env = _Env('ub-1');
      await _seed(env);
      final book = _userBook('ub-1');
      final snapshot = await env.restoreService().capture(userBook: book);

      final observed = <BookRestoreStep>[];
      final report = await env
          .restoreService(onStep: observed.add)
          .restore(BookRestorePlan.forBook('ub-1'), snapshot);

      expect(report.isClean, isTrue, reason: report.toString());
      expect(observed, [
        BookRestoreStep.book,
        BookRestoreStep.trophies,
        BookRestoreStep.quickMemoDraft,
        BookRestoreStep.readingQueue,
        BookRestoreStep.shelves,
        BookRestoreStep.sessions,
      ]);
      // 削除計画の逆順であること（先頭が sessions の逆＝最後に実行）
      expect(observed.last, BookRestoreStep.sessions);
      expect(observed[1], BookRestoreStep.trophies);
    });

    test('途中ステップが失敗しても残りを続行し report に載る（throw しない）', () async {
      final env = _Env('ub-1');
      await _seed(env);
      final snapshot =
          await env.restoreService().capture(userBook: _userBook('ub-1'));
      await env.deletionService().run(BookDeletionPlan.forBook('ub-1'));

      final observed = <BookRestoreStep>[];
      final report = await env
          .restoreService(onStep: observed.add, failShelf: true)
          .restore(BookRestorePlan.forBook('ub-1'), snapshot);

      expect(report.hasFailures, isTrue);
      expect(report.failedSteps, [BookRestoreStep.shelves]);
      // 失敗後も後続（sessions）が走っている
      expect(observed.last, BookRestoreStep.sessions);
      expect(env.sessions.where((s) => s.userBookId == 'ub-1').length, 2);
      expect(env.drafts['ub-1'], isNotNull);
      // 本体・セッション・キュー・下書きは戻り、棚だけ失敗 → 5件
      expect(report.restoredCount, 5);
    });

    test('対象外の本のセッション・棚・キューを巻き込まない', () async {
      final env = _Env('ub-1');
      await _seed(env);
      // 別の本も削除対象と取り違えないこと
      final otherSnapshot =
          await env.restoreService().capture(userBook: _userBook('ub-other'));

      // ub-other のスナップショットを ub-1 の計画で復元しようとしても何もしない
      final mismatched = await env
          .restoreService()
          .restore(BookRestorePlan.forBook('ub-1'), otherSnapshot);
      expect(mismatched.restoredCount, 0);
      expect(env.journal, isEmpty);

      // 正しい対象の復元でも他書のエントリは減らない
      await env.deletionService().run(BookDeletionPlan.forBook('ub-1'));
      final afterDelete = await env.queueRepo.loadEntries();
      final snapshot = (await env.restoreService().capture(
            userBook: _userBook('ub-other'),
          ));
      await env
          .restoreService()
          .restore(BookRestorePlan.forBook('ub-other'), snapshot);
      final after = await env.queueRepo.loadEntries();
      expect(after.map((e) => e.userBookId), contains('ub-other'));
      // ub-1 の削除で減った分（1件）がそのまま。ub-other の1件は増えない
      expect(after.length, afterDelete.length);
      expect(after.length, 1);
      // 対象外の本のセッションは失われていない
      expect(env.sessions.any((s) => s.userBookId == 'ub-other'), isTrue);
    });
  });
}
