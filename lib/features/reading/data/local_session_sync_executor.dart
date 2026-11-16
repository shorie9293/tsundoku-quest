/// 同期計画の実行層。
///
/// I/O はすべて関数注入（push / removeLocal）で外に出してあるため、
/// この層自身は副作用も例外も持たない。呼び出し側（リポジトリ）が
/// Supabase と Hive を結線する。
library;

import '../../../domain/models/reading_session.dart';
import '../domain/local_session_sync.dart';

/// リモートへの登録。失敗は例外で表現する。
typedef SessionPush = Future<void> Function(ReadingSession session);

/// ローカル行の掃除。印行 → 元キー行の順に消すことを期待する。
typedef SessionLocalRemoval = Future<void> Function(
  String rawId,
  String markedId,
);

/// 1回の同期の結果。
class LocalSessionSyncReport {
  const LocalSessionSyncReport({
    this.pushed = 0,
    this.alreadyPresent = 0,
    this.failed = 0,
    this.cleaned = 0,
    this.failedRawIds = const [],
  });

  /// リモートへ新規登録できた件数。
  final int pushed;

  /// 既にリモートに存在した（重複キー）＝反映済みと解釈した件数。
  final int alreadyPresent;

  /// 反映も掃除もできなかった件数（ローカルに残して再試行する）。
  final int failed;

  /// ローカル行を掃除できた件数（push 成功・反映済み・orphan を含む）。
  final int cleaned;

  /// 失敗した元キー（観測用。ローカルに残っている行）。
  final List<String> failedRawIds;

  bool get hasFailures => failed > 0;

  @override
  String toString() => 'LocalSessionSyncReport(pushed: $pushed, '
      'alreadyPresent: $alreadyPresent, failed: $failed, '
      'cleaned: $cleaned)';
}

/// 同期計画を1件ずつ順に実行する。
///
/// 契約:
/// - 絶対に throw しない（1件の失敗で残りを止めない）
/// - push 成功 → ローカル行を掃除
/// - 重複キー → 反映済みとみなしてローカル行を掃除
/// - それ以外の失敗 → ローカル行を残す（データ消失防止）
/// - removeLocal 自体が投げても握り、failed に載せて継続
/// - 同じ plan を2回 run しても終端状態は同一（2回目は重複キーで掃除）
class LocalSessionSyncExecutor {
  const LocalSessionSyncExecutor({
    required SessionPush push,
    required SessionLocalRemoval removeLocal,
  })  : _push = push,
        _removeLocal = removeLocal;

  final SessionPush _push;
  final SessionLocalRemoval _removeLocal;

  Future<LocalSessionSyncReport> run(LocalSessionSyncPlan plan) async {
    var pushed = 0;
    var alreadyPresent = 0;
    var failed = 0;
    var cleaned = 0;
    final failedRawIds = <String>[];

    for (final entry in plan.entries) {
      Object? pushError;
      try {
        await _push(entry.session);
      } catch (e) {
        pushError = e;
      }

      if (pushError == null) {
        pushed++;
      } else if (LocalSessionSyncPlanner.decideAfterPush(error: pushError) ==
          SessionSyncDecision.keepLocal) {
        // 反映できていない。ローカル行は残して次回再試行する。
        failed++;
        failedRawIds.add(entry.rawId);
        continue;
      } else {
        alreadyPresent++;
      }

      // push 成功 or 反映済み → ローカル行（印＋元キー）を掃除する。
      if (await _removeQuietly(entry.rawId, entry.markedId)) {
        cleaned++;
      } else {
        failed++;
        failedRawIds.add(entry.rawId);
      }
    }

    for (final markedId in plan.orphanMarkedIds) {
      if (!markedId.startsWith(LocalSessionSyncPlanner.localPrefix)) continue;
      final rawId =
          markedId.substring(LocalSessionSyncPlanner.localPrefix.length);
      if (await _removeQuietly(rawId, markedId)) {
        cleaned++;
      } else {
        failed++;
        failedRawIds.add(rawId);
      }
    }

    return LocalSessionSyncReport(
      pushed: pushed,
      alreadyPresent: alreadyPresent,
      failed: failed,
      cleaned: cleaned,
      failedRawIds: List.unmodifiable(failedRawIds),
    );
  }

  /// 掃除の失敗を握りつぶして成否だけ返す。
  Future<bool> _removeQuietly(String rawId, String markedId) async {
    try {
      await _removeLocal(rawId, markedId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
