import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book_shelf.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/data/book_deletion_service.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/book_deletion_plan.dart';
import 'package:tsundoku_quest/features/history/data/reading_habit_heatmap_service.dart';
import 'package:tsundoku_quest/features/reading/data/quick_memo_draft_store.dart';
import 'package:tsundoku_quest/features/reading/domain/quick_memo.dart';
import 'package:tsundoku_quest/shared/providers/book_data_provider.dart';

/// 親探針: 子の個別試練では撃てない「合成の不変条件」を独立に撃つ。
///
/// 1. セッション実体（バッキングストア）→ 連鎖削除 → ヒートマップ集計 の合成
/// 2. 削除順序そのものの固定
/// 3. 部分失敗でも後続が走り、例外が外へ出ない
/// 4. 対象外の蔵書データを巻き込まない
/// 5. removeUserBook → service への到達（即時UI反映と両立）
ReadingSession _session({
  required String id,
  required String userBookId,
  required int minutes,
  String startedAt = '2026-11-02T10:00:00',
}) =>
    ReadingSession(
      id: id,
      userBookId: userBookId,
      startedAt: startedAt,
      endedAt: '2026-11-02T10:30:00',
      startPage: 1,
      endPage: 20,
      durationMinutes: minutes,
      createdAt: '2026-11-02T10:00:00',
    );

UserBook _userBook(String id) => UserBook(
      id: id,
      userId: 'u-1',
      bookId: 'b-$id',
      status: BookStatus.tsundoku,
      medium: BookMedium.physical,
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  group('親探針: 蔵書削除の連鎖と統計の整合', () {
    test('孤児セッションが消えるとヒートマップの totalMinutes が減る', () async {
      // 実体となるバッキングストア（セッションの唯一の真実）
      final sessions = <ReadingSession>[
        _session(id: 's1', userBookId: 'ub-del', minutes: 40),
        _session(id: 's2', userBookId: 'ub-del', minutes: 20),
        _session(id: 's3', userBookId: 'ub-keep', minutes: 15),
      ];

      final before =
          ReadingHabitHeatmapService.build(sessions: List.of(sessions));
      expect(before.totalMinutes, 75);
      expect(before.totalSessions, 3);

      final service = BookDeletionService(
        loadSessions: (id) async =>
            sessions.where((s) => s.userBookId == id).toList(),
        deleteSession: (sessionId) async {
          sessions.removeWhere((s) => s.id == sessionId);
        },
      );

      final report = await service.run(BookDeletionPlan.forBook('ub-del'));
      expect(report.isClean, isTrue);

      // バッキングストアから孤児が消えている
      expect(sessions.map((s) => s.id), ['s3']);

      final after =
          ReadingHabitHeatmapService.build(sessions: List.of(sessions));
      expect(after.totalMinutes, 15,
          reason: '削除した本の読書時間が統計から消えること');
      expect(after.totalSessions, 1);
    });

    test('削除順序が plan の宣言順に固定される', () async {
      final order = <BookDeletionStep>[];
      final draft = InMemoryQuickMemoDraftStore();
      final service = BookDeletionService(
        loadSessions: (_) async => const <ReadingSession>[],
        deleteSession: (_) async {},
        loadShelves: () async => const <BookShelf>[],
        removeBookFromShelf: (_, __) async =>
            throw StateError('呼ばれないはず'),
        loadQueue: () async => const <ReadingQueueEntry>[],
        saveQueue: (_) async {},
        draftStore: draft,
        onStep: order.add,
      );

      await service.run(BookDeletionPlan.forBook('ub-1'));

      expect(order, [
        BookDeletionStep.sessions,
        BookDeletionStep.shelves,
        BookDeletionStep.readingQueue,
        BookDeletionStep.quickMemoDraft,
        BookDeletionStep.trophies,
      ]);
    });

    test('セッション削除が失敗しても棚・キュー・下書きの掃除は続行される', () async {
      final draft = InMemoryQuickMemoDraftStore();
      await draft.save('ub-1', QuickMemoDraft(body: '下書き', updatedAt: DateTime(2026, 11, 7)));
      var queueSaved = 0;
      final queue = <ReadingQueueEntry>[
        ReadingQueueEntry(userBookId: 'ub-1', position: 1, addedAt: DateTime(2026, 11, 1)),
      ];

      final service = BookDeletionService(
        loadSessions: (_) async =>
            [_session(id: 's1', userBookId: 'ub-1', minutes: 10)],
        deleteSession: (_) async => throw StateError('ネットワーク断'),
        loadShelves: () async => [
          BookShelf(
            id: 'sh-1',
            name: '積読棚',
            colorValue: 0,
            createdAt: '2026-11-01T00:00:00Z',
            userBookIds: const ['ub-1', 'ub-2'],
          ),
        ],
        removeBookFromShelf: (shelfId, userBookId) async => BookShelf(
          id: shelfId,
          name: '積読棚',
          colorValue: 0,
          createdAt: '2026-11-01T00:00:00Z',
          userBookIds: const ['ub-2'],
        ),
        loadQueue: () async => List.of(queue),
        saveQueue: (entries) async {
          queueSaved++;
          queue
            ..clear()
            ..addAll(entries);
        },
        draftStore: draft,
      );

      final report = await service.run(BookDeletionPlan.forBook('ub-1'));

      expect(report.hasFailures, isTrue);
      expect(report.failedSteps, [BookDeletionStep.sessions]);
      // 後続は実行されている
      expect(queueSaved, 1);
      expect(queue, isEmpty);
      expect(draft.clearCalls, contains('ub-1'));
      expect(await draft.load('ub-1'), isNull);
    });

    test('対象外の蔵書のセッション・キューを巻き込まない', () async {
      final sessions = <ReadingSession>[
        _session(id: 's1', userBookId: 'ub-del', minutes: 10),
        _session(id: 's2', userBookId: 'ub-keep', minutes: 30),
      ];
      final queue = <ReadingQueueEntry>[
        ReadingQueueEntry(userBookId: 'ub-del', position: 1, addedAt: DateTime(2026, 11, 1)),
        ReadingQueueEntry(userBookId: 'ub-keep', position: 2, addedAt: DateTime(2026, 11, 2)),
      ];
      final service = BookDeletionService(
        loadSessions: (id) async =>
            sessions.where((s) => s.userBookId == id).toList(),
        deleteSession: (sessionId) async {
          sessions.removeWhere((s) => s.id == sessionId);
        },
        loadQueue: () async => List.of(queue),
        saveQueue: (entries) async {
          queue
            ..clear()
            ..addAll(entries);
        },
      );

      await service.run(BookDeletionPlan.forBook('ub-del'));

      expect(sessions.map((s) => s.id), ['s2']);
      expect(queue.map((e) => e.userBookId), ['ub-keep']);
    });

    test('removeUserBook は即時UI反映しつつ連鎖削除へ到達する', () async {
      final sessions = <ReadingSession>[
        _session(id: 's1', userBookId: 'ub-1', minutes: 25),
      ];
      final service = BookDeletionService(
        loadSessions: (id) async =>
            sessions.where((s) => s.userBookId == id).toList(),
        deleteSession: (sessionId) async {
          sessions.removeWhere((s) => s.id == sessionId);
        },
      );
      final notifier = BookDataNotifier(null, null, null, null, null, service);
      notifier.addUserBook(_userBook('ub-1'));

      notifier.removeUserBook('ub-1');
      // 同期直後: 一覧からは既に消えている（既存契約）
      expect(notifier.state.userBooks, isEmpty);

      await pumpEventQueue();
      expect(sessions, isEmpty, reason: '投げっぱなしの連鎖削除が実行されること');
    });
  });
}
