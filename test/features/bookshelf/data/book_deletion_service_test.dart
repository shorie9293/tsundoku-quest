import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book_shelf.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/bookshelf/data/book_deletion_service.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/book_deletion_plan.dart';
import 'package:tsundoku_quest/features/reading/data/quick_memo_draft_store.dart';

ReadingSession _session(String id, String userBookId) => ReadingSession(
      id: id,
      userBookId: userBookId,
      startedAt: '2026-01-01T00:00:00Z',
      startPage: 1,
      createdAt: '2026-01-01T00:00:00Z',
    );

BookShelf _shelf(String id, List<String> userBookIds) => BookShelf(
      id: id,
      name: id,
      colorValue: 0,
      createdAt: '2026-01-01T00:00:00Z',
      userBookIds: userBookIds,
    );

ReadingQueueEntry _entry(String userBookId, int position) => ReadingQueueEntry(
      userBookId: userBookId,
      position: position,
      addedAt: DateTime.utc(2026, 1, 1),
    );

/// すべての依存を記録するフェイク。呼出順を [calls] に積む。
class _Recorder {
  final List<String> calls = [];
  final List<BookDeletionStep> stepHooks = [];
  final List<List<ReadingQueueEntry>> savedQueues = [];
  final List<String> deletedSessionIds = [];
  final List<String> shelfDetachCalls = [];
  final List<String> trophyCalls = [];
  final InMemoryQuickMemoDraftStore store = InMemoryQuickMemoDraftStore();

  BookDeletionService build({
    bool failQueueLoad = false,
    bool failShelfLoad = false,
  }) {
    return BookDeletionService(
      loadSessions: (userBookId) async {
        calls.add('loadSessions($userBookId)');
        return [_session('s-1', userBookId), _session('s-2', userBookId)];
      },
      deleteSession: (sessionId) async {
        calls.add('deleteSession($sessionId)');
        deletedSessionIds.add(sessionId);
      },
      loadShelves: () async {
        calls.add('loadShelves');
        if (failShelfLoad) throw StateError('棚の読み込みに失敗');
        return [
          _shelf('shelf-a', ['ub-1', 'ub-2']),
          _shelf('shelf-b', ['ub-2']),
        ];
      },
      removeBookFromShelf: (shelfId, userBookId) async {
        calls.add('removeBookFromShelf($shelfId,$userBookId)');
        shelfDetachCalls.add('$shelfId:$userBookId');
        return _shelf(shelfId, ['ub-2']);
      },
      loadQueue: () async {
        calls.add('loadQueue');
        if (failQueueLoad) throw StateError('キューの読み込みに失敗');
        return [_entry('ub-1', 1), _entry('ub-2', 2)];
      },
      saveQueue: (entries) async {
        calls.add('saveQueue(${entries.map((e) => e.userBookId).join(',')})');
        savedQueues.add(entries);
      },
      draftStore: store,
      trophyCleanup: (userBookId) {
        calls.add('trophyCleanup($userBookId)');
        trophyCalls.add(userBookId);
      },
      onStep: (step) {
        stepHooks.add(step);
        calls.add('step:${step.name}');
      },
    );
  }
}

void main() {
  group('BookDeletionService', () {
    test('呼出順そのものが plan.steps の順序どおり', () async {
      final recorder = _Recorder();
      final service = recorder.build();

      await service.run(BookDeletionPlan.forBook('ub-1'));

      expect(recorder.stepHooks, [
        BookDeletionStep.sessions,
        BookDeletionStep.shelves,
        BookDeletionStep.readingQueue,
        BookDeletionStep.quickMemoDraft,
        BookDeletionStep.trophies,
      ]);
      // 実際の I/O 呼出もステップ順に並ぶ
      expect(recorder.calls, [
        'step:sessions',
        'loadSessions(ub-1)',
        'deleteSession(s-1)',
        'deleteSession(s-2)',
        'step:shelves',
        'loadShelves',
        'removeBookFromShelf(shelf-a,ub-1)',
        'step:readingQueue',
        'loadQueue',
        'saveQueue(ub-2)',
        'step:quickMemoDraft',
        'step:trophies',
        'trophyCleanup(ub-1)',
      ]);
      expect(recorder.store.clearCalls, ['ub-1']);
    });

    test('中途ステップが throw しても後続が実行され、例外は外へ出ない', () async {
      final recorder = _Recorder();
      final service = recorder.build(failShelfLoad: true);

      final report = await service.run(BookDeletionPlan.forBook('ub-1'));

      expect(report.hasFailures, isTrue);
      expect(report.isClean, isFalse);
      expect(report.failedSteps, [BookDeletionStep.shelves]);
      expect(report.failures[BookDeletionStep.shelves], isA<StateError>());
      // 棚の失敗後もキュー・下書き・戦利品は実行されている
      expect(recorder.stepHooks, BookDeletionStep.values);
      expect(recorder.savedQueues.single.map((e) => e.userBookId), ['ub-2']);
      expect(recorder.store.clearCalls, ['ub-1']);
      expect(recorder.trophyCalls, ['ub-1']);
    });

    test('キュー読み込みが throw しても report に載り、例外は出ない', () async {
      final recorder = _Recorder();
      final service = recorder.build(failQueueLoad: true);

      final report = await service.run(BookDeletionPlan.forBook('ub-1'));

      expect(report.hasFailures, isTrue);
      expect(report.failedSteps, [BookDeletionStep.readingQueue]);
      expect(recorder.store.clearCalls, ['ub-1']);
      expect(recorder.trophyCalls, ['ub-1']);
    });

    test('全依存 null でも throw せず isClean（全ステップ skip）', () async {
      final service = BookDeletionService();

      final report = await service.run(BookDeletionPlan.forBook('ub-1'));

      expect(report.hasFailures, isFalse);
      expect(report.isClean, isTrue);
      expect(report.failedSteps, isEmpty);
    });

    test('該当IDのみ削除し、他IDは不変', () async {
      final recorder = _Recorder();
      final service = recorder.build();

      await service.run(BookDeletionPlan.forBook('ub-1'));

      expect(recorder.deletedSessionIds, ['s-1', 's-2']);
      // ub-1 を含む棚のみ外す（shelf-b は触らない）
      expect(recorder.shelfDetachCalls, ['shelf-a:ub-1']);
      // キューは ub-1 だけ除かれ ub-2 が残る
      expect(recorder.savedQueues.single.map((e) => e.userBookId), ['ub-2']);
      expect(recorder.trophyCalls, ['ub-1']);
      expect(recorder.store.clearCalls, ['ub-1']);
    });

    test('該当IDがキューに無ければ保存しない（無駄書き込みなし）', () async {
      final calls = <String>[];
      final service = BookDeletionService(
        loadQueue: () async => [_entry('ub-9', 1)],
        saveQueue: (entries) async => calls.add('save'),
      );

      final report = await service.run(BookDeletionPlan.forBook('ub-1'));

      expect(report.isClean, isTrue);
      expect(calls, isEmpty);
    });

    test('onStep フックが throw しても削除は継続する', () async {
      final trophies = <String>[];
      final service = BookDeletionService(
        trophyCleanup: trophies.add,
        onStep: (step) => throw StateError('フック故障'),
      );

      final report = await service.run(BookDeletionPlan.forBook('ub-1'));

      expect(trophies, ['ub-1']);
      expect(report.isClean, isTrue);
    });
  });
}
