/// ローカル退避セッションのリモート同期に関する純粋層。
///
/// I/O も throw もしない（Dart 標準とドメインモデルのみ）。
/// Supabase 型への依存も持たないため、重複キー判定は
/// 「code/message を文字列として受け取る」形に閉じてある。
/// 例外→code/message の型判定は実行層（data 層）が担う。
library;

import '../../../domain/models/reading_session.dart';

/// local: 印付きで保存されたセッションであることを示すプレフィックス。
const String localSessionMarkerPrefix = 'local:';

/// 同期対象の1件。`rawId` は印を剥がした元キー（＝元キー行の ID）。
class LocalSessionSyncEntry {
  const LocalSessionSyncEntry({required this.rawId, required this.session});

  /// 印を剥がした元キー。box の元キー行を指す。
  final String rawId;

  /// リモートへ送る完了データ（元キー行の中身）。
  final ReadingSession session;

  /// 印付き行のキー。掃除のときに元キーと対で消す。
  String get markedId => '$localSessionMarkerPrefix$rawId';

  @override
  String toString() => 'LocalSessionSyncEntry(rawId: $rawId)';
}

/// 同期計画。`entries` を順に処理し、`orphanMarkedIds` は印だけ掃除する。
class LocalSessionSyncPlan {
  const LocalSessionSyncPlan({
    required this.entries,
    required this.orphanMarkedIds,
  });

  /// リモートへ push してからローカル行を消す対象（markedIds の順で安定）。
  final List<LocalSessionSyncEntry> entries;

  /// 印はあるが元キー行が無い行。push せず印だけ消す。
  final List<String> orphanMarkedIds;

  /// 何もしなくてよいか（呼び出し側の no-op 判定用）。
  bool get isEmpty => entries.isEmpty && orphanMarkedIds.isEmpty;

  @override
  String toString() => 'LocalSessionSyncPlan(entries: ${entries.length}, '
      'orphans: ${orphanMarkedIds.length})';
}

/// push 後のローカル行の扱い。
enum SessionSyncDecision {
  /// リモートへ反映済み。ローカル行（印＋元キー）を消す。
  deleteLocal,

  /// 反映できていない。ローカル行を残して次回再試行する。
  keepLocal,
}

/// 例外から「重複キー判定」に必要な最小情報。
///
/// 実行層が `PostgrestException` 等から詰め替える境界値。
/// 純粋層は Supabase 型を知らない。
class SyncErrorInfo {
  const SyncErrorInfo({this.code, this.message});

  /// Postgres の SQLSTATE（重複キーは '23505'）。
  final String? code;

  /// エラーメッセージ（'duplicate key …' 等）。
  final String? message;

  /// 任意の例外から code/message を寛容に取り出す。
  ///
  /// - 自身なら そのまま
  /// - `code` / `message` を持つオブジェクト（PostgrestException 等）は
  ///   ダックタイピングで読む（型 import を避けるため dynamic 経由）
  /// - 取れなければ toString() だけを持つ情報として返す
  factory SyncErrorInfo.from(Object error) {
    if (error is SyncErrorInfo) return error;
    String? code;
    String? message;
    try {
      final dynamic e = error;
      final dynamic c = e.code;
      if (c is String && c.isNotEmpty) code = c;
    } catch (_) {
      // code を持たない例外は無視する
    }
    try {
      final dynamic e = error;
      final dynamic m = e.message;
      if (m is String && m.isNotEmpty) message = m;
    } catch (_) {
      // message を持たない例外は無視する
    }
    return SyncErrorInfo(code: code, message: message);
  }
}

/// 重複キー違反（＝既にリモートへ反映済み）かどうか。
///
/// 1) code が '23505' なら真
/// 2) message / toString に 'duplicate key'、'violates unique constraint'、
///    '23505' のいずれかを含めば真
/// 3) それ以外は偽
bool isAlreadyPresentError(Object error) {
  final info = SyncErrorInfo.from(error);
  if (info.code == '23505') return true;

  String text = info.message ?? '';
  try {
    text = '$text ${error.toString()}';
  } catch (_) {
    // toString が投げる異常オブジェクトでも判定は続行する
  }
  return text.contains('duplicate key') ||
      text.contains('violates unique constraint') ||
      text.contains('23505');
}

/// ローカル box の状態から同期計画を立てる純粋関数群。
class LocalSessionSyncPlanner {
  const LocalSessionSyncPlanner._();

  /// 印のプレフィックス（単一の出所）。
  static const String localPrefix = localSessionMarkerPrefix;

  /// [markedIds]（box 上の `local:` 付きキー）と [rawById]（元キー→行）から
  /// 同期計画を作る。
  ///
  /// - 順序は [markedIds] の順で安定（同じ入力なら同じ結果）
  /// - 完了データ（durationMinutes と endedAt が両方非 null）だけを entries に
  /// - 元キー行が無い印は orphanMarkedIds（印だけ掃除）
  /// - 未完了の行はどちらにも載せない（読書中。次回同期で完了し得る）
  /// - 印でない ID は無視する
  static LocalSessionSyncPlan plan({
    required List<String> markedIds,
    required Map<String, ReadingSession> rawById,
  }) {
    final entries = <LocalSessionSyncEntry>[];
    final orphans = <String>[];

    for (final markedId in markedIds) {
      if (!markedId.startsWith(localPrefix)) continue;
      final rawId = markedId.substring(localPrefix.length);
      if (rawId.isEmpty) continue;

      final session = rawById[rawId];
      if (session == null) {
        // 元キー行が無い＝印だけが残っている。印を掃除する。
        orphans.add(markedId);
        continue;
      }
      if (session.durationMinutes == null || session.endedAt == null) {
        // 読書中。ローカルに残し、完了後の同期に委ねる。
        continue;
      }
      entries.add(LocalSessionSyncEntry(rawId: rawId, session: session));
    }

    return LocalSessionSyncPlan(entries: entries, orphanMarkedIds: orphans);
  }

  /// push の結果（[error] が null なら成功）からローカル行の扱いを決める。
  ///
  /// 重複キーは「リモートに同一 PK が既にある＝反映済み」と解釈する。
  /// これを失敗扱いにすると delete に到達せず、再試行が永久に
  /// 重複キーで失敗して二重計上が固定される。
  static SessionSyncDecision decideAfterPush({Object? error}) {
    if (error == null) return SessionSyncDecision.deleteLocal;
    if (isAlreadyPresentError(error)) return SessionSyncDecision.deleteLocal;
    return SessionSyncDecision.keepLocal;
  }
}
