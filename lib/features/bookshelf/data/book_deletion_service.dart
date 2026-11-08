/// 蔵書削除時の連鎖削除（孤児データ掃除）サービス。
///
/// [BookDeletionPlan] のステップ順を厳守して各データを掃除する。
/// あるステップが失敗しても例外は外へ出さず、残りのステップを継続する。
library;

import 'package:tsundoku_quest/core/logging/app_logger.dart';
import 'package:tsundoku_quest/domain/models/book_shelf.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/book_deletion_plan.dart';
import 'package:tsundoku_quest/features/reading/data/quick_memo_draft_store.dart';

/// 連鎖削除の結果。失敗しても例外は投げず、ここに記録する。
class BookDeletionReport {
  const BookDeletionReport([this.failures = const {}]);

  /// 失敗したステップとその原因
  final Map<BookDeletionStep, Object> failures;

  /// 失敗したステップ（enum 宣言順）
  List<BookDeletionStep> get failedSteps => BookDeletionStep.values
      .where(failures.containsKey)
      .toList(growable: false);

  bool get hasFailures => failures.isNotEmpty;

  /// 全ステップが例外なく完了した
  bool get isClean => !hasFailures;

  @override
  String toString() => 'BookDeletionReport(failures: ${failedSteps.join(',')})';
}

/// 蔵書1冊分の孤児データを順序どおりに掃除する。
///
/// 依存はすべて任意。null のステップは「対象なし」としてスキップする。
class BookDeletionService {
  BookDeletionService({
    this.loadSessions,
    this.deleteSession,
    this.loadShelves,
    this.removeBookFromShelf,
    this.loadQueue,
    this.saveQueue,
    this.draftStore,
    this.trophyCleanup,
    this.onStep,
  });

  /// 対象蔵書のセッション一覧を取得する
  final Future<List<ReadingSession>> Function(String userBookId)? loadSessions;

  /// セッションを1件削除する（id 指定）
  final Future<void> Function(String sessionId)? deleteSession;

  /// 全棚を取得する
  final Future<List<BookShelf>> Function()? loadShelves;

  /// 棚から蔵書を取り除く
  final Future<BookShelf> Function(String shelfId, String userBookId)?
      removeBookFromShelf;

  /// 読書キューを取得する
  final Future<List<ReadingQueueEntry>> Function()? loadQueue;

  /// 読書キューを保存する
  final Future<void> Function(List<ReadingQueueEntry>)? saveQueue;

  /// クイックメモ下書きストア
  final QuickMemoDraftStore? draftStore;

  /// 戦利品クリーンアップ（既存 trophyCleanup と同シグネチャ）
  final void Function(String userBookId)? trophyCleanup;

  /// 各ステップ開始時に呼ばれるフック（試練で順序を観測する）
  final void Function(BookDeletionStep step)? onStep;

  /// [plan] のステップを順序どおりに実行する。絶対に throw しない。
  Future<BookDeletionReport> run(BookDeletionPlan plan) async {
    final failures = <BookDeletionStep, Object>{};
    for (final step in plan.steps) {
      try {
        onStep?.call(step);
      } catch (e, stack) {
        // 観測フックの失敗は削除処理を止めない
        appLog.warn('[BookDeletion] onStep($step) 失敗', e, stack);
      }
      try {
        await _runStep(step, plan.userBookId);
      } catch (e, stack) {
        failures[step] = e;
        appLog.warn(
          '[BookDeletion] ${plan.userBookId} の $step 掃除に失敗（継続）',
          e,
          stack,
        );
      }
    }
    if (failures.isEmpty) {
      appLog.debug('[BookDeletion] ${plan.userBookId} の連鎖削除 完了');
    }
    return BookDeletionReport(failures);
  }

  Future<void> _runStep(BookDeletionStep step, String userBookId) async {
    switch (step) {
      case BookDeletionStep.sessions:
        await _deleteSessions(userBookId);
      case BookDeletionStep.shelves:
        await _detachFromShelves(userBookId);
      case BookDeletionStep.readingQueue:
        await _removeFromQueue(userBookId);
      case BookDeletionStep.quickMemoDraft:
        await draftStore?.clear(userBookId);
      case BookDeletionStep.trophies:
        trophyCleanup?.call(userBookId);
    }
  }

  Future<void> _deleteSessions(String userBookId) async {
    final load = loadSessions;
    final remove = deleteSession;
    if (load == null || remove == null) return;
    final sessions = await load(userBookId);
    for (final session in sessions) {
      if (session.userBookId != userBookId) continue;
      await remove(session.id);
    }
  }

  Future<void> _detachFromShelves(String userBookId) async {
    final load = loadShelves;
    final detach = removeBookFromShelf;
    if (load == null || detach == null) return;
    final shelves = await load();
    for (final shelf in shelves) {
      if (!shelf.userBookIds.contains(userBookId)) continue;
      await detach(shelf.id, userBookId);
    }
  }

  Future<void> _removeFromQueue(String userBookId) async {
    final load = loadQueue;
    final save = saveQueue;
    if (load == null || save == null) return;
    final entries = await load();
    if (!entries.any((e) => e.userBookId == userBookId)) return;
    final remaining =
        entries.where((e) => e.userBookId != userBookId).toList(growable: false);
    await save(remaining);
  }
}
