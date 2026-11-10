/// 蔵書の単体削除を取り消す（Undo）連鎖復元サービス。
///
/// [BookRestorePlan] のステップ順（削除計画の逆順）を厳守して復元する。
/// あるステップが失敗しても例外は外へ出さず、残りのステップを継続する。
/// 依存は全て任意関数注入。null のステップは「対象なし」としてスキップする。
library;

import 'dart:async';

import 'package:tsundoku_quest/core/logging/app_logger.dart';
import 'package:tsundoku_quest/domain/models/book_shelf.dart';
import 'package:tsundoku_quest/domain/models/reading_queue_entry.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/domain/models/war_trophy.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/book_restore_plan.dart';
import 'package:tsundoku_quest/features/reading/data/quick_memo_draft_store.dart';
import 'package:tsundoku_quest/features/reading/domain/quick_memo.dart';

/// 連鎖復元の結果。失敗しても例外は投げず、ここに記録する。
class BookRestoreReport {
  const BookRestoreReport({
    this.restoredCount = 0,
    this.failures = const {},
  });

  /// 復元できた件数（本体・子データの合計）
  final int restoredCount;

  /// 失敗したステップとその原因
  final Map<BookRestoreStep, Object> failures;

  /// 失敗したステップ（復元順）
  List<BookRestoreStep> get failedSteps => BookRestoreStep.values
      .where(failures.containsKey)
      .toList(growable: false);

  bool get hasFailures => failures.isNotEmpty;

  /// 全ステップが例外なく完了した
  bool get isClean => !hasFailures;

  /// ユーザー向け1行要約（SnackBar 用）
  String get summary {
    if (!hasFailures) return '$restoredCount件を復元しました';
    return '$restoredCount件を復元しました（失敗: ${failedSteps.length}件）';
  }

  @override
  String toString() => 'BookRestoreReport(restored: $restoredCount, '
      'failures: ${failedSteps.join(',')})';
}

/// 蔵書1冊分の連鎖削除を取り消す（削除前スナップショットから逆順復元する）。
class BookRestoreService {
  BookRestoreService({
    this.loadSessions,
    this.loadShelves,
    this.loadQueue,
    this.loadTrophies,
    this.addUserBook,
    this.addSession,
    this.addBookToShelf,
    this.restoreQueueEntries,
    this.saveDraft,
    this.addTrophy,
    this.draftStore,
    this.onStep,
  });

  // ─── スナップショット取得用（削除前）───

  /// 対象蔵書のセッション一覧を取得する
  final Future<List<ReadingSession>> Function(String userBookId)? loadSessions;

  /// 全棚を取得する
  final Future<List<BookShelf>> Function()? loadShelves;

  /// 読書キューを取得する
  final Future<List<ReadingQueueEntry>> Function()? loadQueue;

  /// 戦利品一覧を取得する
  final Future<List<WarTrophy>> Function()? loadTrophies;

  /// クイックメモ下書きストア
  final QuickMemoDraftStore? draftStore;

  // ─── 復元用（削除後）───

  /// 蔵書本体を戻す
  final void Function(UserBook userBook)? addUserBook;

  /// セッションを登録し直す（startedAt/endedAt/duration を保持したまま）
  final Future<void> Function(ReadingSession session)? addSession;

  /// 棚へ蔵書を戻す
  final Future<void> Function(String shelfId, String userBookId)?
      addBookToShelf;

  /// 読書キューから消えたエントリを戻す（他書のエントリは巻き込まない）
  final Future<void> Function(List<ReadingQueueEntry> entries)?
      restoreQueueEntries;

  /// クイックメモ下書きを書き戻す
  final Future<void> Function(String userBookId, QuickMemoDraft draft)?
      saveDraft;

  /// 戦利品を戻す
  final void Function(WarTrophy trophy)? addTrophy;

  /// 各ステップ開始時に呼ばれるフック（試練で順序を観測する）
  final void Function(BookRestoreStep step)? onStep;

  /// 削除**前**に呼ぶ。復元に必要な情報をかき集める。
  ///
  /// 取得に失敗した種別は空として扱い、例外は外へ出さない
  /// （削除操作そのものを止めないため）。
  Future<BookRestoreSnapshot> capture({required UserBook userBook}) async {
    final userBookId = userBook.id;

    var sessions = const <ReadingSession>[];
    final loadS = loadSessions;
    if (loadS != null) {
      try {
        sessions = (await loadS(userBookId))
            .where((s) => s.userBookId == userBookId)
            .toList(growable: false);
      } catch (e, stack) {
        appLog.warn('[BookRestore] $userBookId のセッション取得に失敗', e, stack);
      }
    }

    var shelfIds = const <String>[];
    final loadSh = loadShelves;
    if (loadSh != null) {
      try {
        shelfIds = (await loadSh())
            .where((shelf) => shelf.userBookIds.contains(userBookId))
            .map((shelf) => shelf.id)
            .toList(growable: false);
      } catch (e, stack) {
        appLog.warn('[BookRestore] $userBookId の棚取得に失敗', e, stack);
      }
    }

    var queueEntries = const <ReadingQueueEntry>[];
    final loadQ = loadQueue;
    if (loadQ != null) {
      try {
        queueEntries = (await loadQ())
            .where((entry) => entry.userBookId == userBookId)
            .toList(growable: false);
      } catch (e, stack) {
        appLog.warn('[BookRestore] $userBookId のキュー取得に失敗', e, stack);
      }
    }

    QuickMemoDraft? draft;
    try {
      draft = await draftStore?.load(userBookId);
    } catch (e, stack) {
      appLog.warn('[BookRestore] $userBookId のメモ下書き取得に失敗', e, stack);
    }

    var trophies = const <WarTrophy>[];
    final loadT = loadTrophies;
    if (loadT != null) {
      try {
        trophies = (await loadT())
            .where((trophy) => trophy.userBookId == userBookId)
            .toList(growable: false);
      } catch (e, stack) {
        appLog.warn('[BookRestore] $userBookId の戦利品取得に失敗', e, stack);
      }
    }

    return BookRestoreSnapshot(
      userBook: userBook,
      sessions: sessions,
      shelfIds: shelfIds,
      queueEntries: queueEntries,
      quickMemoDraft: draft,
      trophies: trophies,
    );
  }

  /// [plan] のステップを順序どおりに実行する。絶対に throw しない。
  Future<BookRestoreReport> restore(
    BookRestorePlan plan,
    BookRestoreSnapshot snapshot,
  ) async {
    if (plan.userBookId != snapshot.userBook.id) {
      // 取り違えは復元しない（他書のデータを巻き込まないための番人）
      appLog.warn(
        '[BookRestore] plan(${plan.userBookId}) と snapshot'
        '(${snapshot.userBook.id}) が不一致のため中止',
      );
      return const BookRestoreReport();
    }

    final failures = <BookRestoreStep, Object>{};
    var restored = 0;

    for (final step in plan.steps) {
      try {
        onStep?.call(step);
      } catch (e, stack) {
        // 観測フックの失敗は復元処理を止めない
        appLog.warn('[BookRestore] onStep($step) 失敗', e, stack);
      }
      try {
        restored += await _runStep(step, snapshot);
      } catch (e, stack) {
        failures[step] = e;
        appLog.warn(
          '[BookRestore] ${snapshot.userBook.id} の $step 復元に失敗（継続）',
          e,
          stack,
        );
      }
    }

    if (failures.isEmpty) {
      appLog.debug('[BookRestore] ${snapshot.userBook.id} の連鎖復元 完了');
    }
    return BookRestoreReport(restoredCount: restored, failures: failures);
  }

  /// 1ステップを実行し、復元件数を返す。
  Future<int> _runStep(
      BookRestoreStep step, BookRestoreSnapshot snapshot) async {
    final userBookId = snapshot.userBook.id;
    switch (step) {
      case BookRestoreStep.book:
        final add = addUserBook;
        if (add == null) return 0;
        add(snapshot.userBook);
        return 1;

      case BookRestoreStep.trophies:
        final add = addTrophy;
        if (add == null || snapshot.trophies.isEmpty) return 0;
        var count = 0;
        for (final trophy in snapshot.trophies) {
          add(trophy);
          count++;
        }
        return count;

      case BookRestoreStep.quickMemoDraft:
        final save = saveDraft;
        final draft = snapshot.quickMemoDraft;
        if (save == null || draft == null) return 0;
        await save(userBookId, draft);
        return 1;

      case BookRestoreStep.readingQueue:
        final restoreQueue = restoreQueueEntries;
        if (restoreQueue == null || snapshot.queueEntries.isEmpty) return 0;
        await restoreQueue(snapshot.queueEntries);
        return snapshot.queueEntries.length;

      case BookRestoreStep.shelves:
        final add = addBookToShelf;
        if (add == null || snapshot.shelfIds.isEmpty) return 0;
        var count = 0;
        for (final shelfId in snapshot.shelfIds) {
          await add(shelfId, userBookId);
          count++;
        }
        return count;

      case BookRestoreStep.sessions:
        final add = addSession;
        if (add == null || snapshot.sessions.isEmpty) return 0;
        var count = 0;
        for (final session in snapshot.sessions) {
          await add(session);
          count++;
        }
        return count;
    }
  }
}
