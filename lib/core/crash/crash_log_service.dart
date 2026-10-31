import 'dart:async';

import 'crash_log_entry.dart';
import 'crash_log_repository.dart';

/// 未捕捉例外を端末内ログへ投げっぱなしで記録する。
///
/// [record] は同期的に戻り、書き込み例外も内部で握る。
/// 呼び出し側（`FlutterError.onError` / `runZonedGuarded`）を絶対に壊さない。
class CrashLogger {
  CrashLogger({
    CrashLogRepository? repository,
    DateTime Function()? clock,
  })  : _repository = repository ?? FileCrashLogRepository(),
        _clock = clock ?? DateTime.now;

  final CrashLogRepository _repository;
  final DateTime Function() _clock;

  CrashLogRepository get repository => _repository;

  /// 1件記録する（awaited しない・例外は握る）。
  void record(Object error, StackTrace? stack, {String kind = 'error'}) {
    try {
      final entry = CrashLogEntry.fromError(
        error,
        stack,
        kind: kind,
        timestamp: _clock(),
      );
      unawaited(
        _repository.append(entry).catchError((Object _) {}),
      );
    } catch (_) {
      // 記録できなくてもアプリは継続する
    }
  }
}

/// 保存済みログの要約（0件なら null）。
///
/// 例: `前回の異常終了 2件（最終 09:31）`
String? summarize(List<CrashLogEntry> entries, {DateTime? now}) {
  if (entries.isEmpty) return null;
  final sorted = [...entries]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final last = sorted.last;
  final base = now ?? DateTime.now();
  final sameDay = last.timestamp.year == base.year &&
      last.timestamp.month == base.month &&
      last.timestamp.day == base.day;
  final hh = last.timestamp.hour.toString().padLeft(2, '0');
  final mm = last.timestamp.minute.toString().padLeft(2, '0');
  final when = sameDay
      ? '$hh:$mm'
      : '${last.timestamp.month}/${last.timestamp.day} $hh:$mm';
  return '前回の異常終了 ${entries.length}件（最終 $when）';
}

/// 直近 [limit] 件を新しい順で返す。
List<CrashLogEntry> recent(List<CrashLogEntry> entries, {int limit = 20}) {
  if (limit <= 0) return const [];
  final sorted = [...entries]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return sorted.take(limit).toList();
}

/// 共有・コピー用のプレーンテキスト化。
String formatCrashLogsForClipboard(List<CrashLogEntry> entries) {
  if (entries.isEmpty) return '';
  final buffer = StringBuffer();
  for (final e in recent(entries, limit: kCrashLogMaxEntries)) {
    buffer.writeln(
      '[${e.timestamp.toIso8601String()}] (${e.kind}) ${e.message}',
    );
    if (e.stackTop.isNotEmpty) buffer.writeln(e.stackTop);
    buffer.writeln('');
  }
  return buffer.toString();
}
