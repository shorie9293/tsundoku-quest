/// 自動バックアップ実行役
///
/// Kanban t_db8484e0 / 改善提案 #188 — 全現世共通仕様
/// 実行可否判定 → JSON 組み立て → 書き込み → 世代整理 を担う。
/// いかなる例外も握り、起動を妨げない。
library;

import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';

/// 実行結果
class AutoBackupResult {
  /// 書き込みを実行したか
  final bool ran;

  /// 書き込んだファイル名（スキップ・失敗時は null）
  final String? fileName;

  /// 削除した旧世代のファイル名
  final List<String> pruned;

  /// 握った例外（成功時は null）
  final Object? error;

  const AutoBackupResult({
    required this.ran,
    this.fileName,
    this.pruned = const [],
    this.error,
  });

  @override
  String toString() =>
      'AutoBackupResult(ran: $ran, fileName: $fileName, pruned: $pruned, error: $error)';
}

/// 起動時1日1回の自動バックアップ
class AutoBackupService {
  final AutoBackupStore store;
  final AutoBackupPolicy policy;
  final DateTime Function() _now;

  AutoBackupService({
    required this.store,
    this.policy = const AutoBackupPolicy(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// 自動バックアップを1回試行する。
  ///
  /// [buildJson] はバックアップ JSON 文字列を組み立てる関数。
  /// 同日再実行は同名上書きで冪等。
  Future<AutoBackupResult> run(Future<String> Function() buildJson) async {
    try {
      final now = _now();
      final entries = await store.list();
      final lastAt = policy.latestCreatedAt(entries);

      if (!policy.shouldRun(lastAt: lastAt, now: now)) {
        return const AutoBackupResult(ran: false);
      }

      final json = await buildJson();
      final fileName = AutoBackupPolicy.fileNameFor(now);
      await store.write(fileName, json);

      final after = await store.list();
      final stale = policy.prune(after);
      for (final entry in stale) {
        await store.delete(entry.fileName);
      }

      return AutoBackupResult(
        ran: true,
        fileName: fileName,
        pruned: [for (final e in stale) e.fileName],
      );
    } catch (e) {
      return AutoBackupResult(ran: false, error: e);
    }
  }
}
