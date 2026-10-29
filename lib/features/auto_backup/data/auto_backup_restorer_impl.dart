/// 自動バックアップの復元実装
///
/// Kanban t_db8484e0 / 改善提案 #188 続編。
/// 手順は固定：read → canRestore 検証 → **現状スナップショットの強制保存**
/// → 既存インポート経路（features/backup）で適用。
/// 例外はすべて捕まえて ok:false に落とす（UI を壊さない）。
library;

import 'package:flutter/foundation.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_restorer.dart';

/// 自動バックアップからの復元
class AutoBackupRestorerImpl implements AutoBackupRestorer {
  /// 保管庫
  final AutoBackupStore store;

  /// 現状 JSON の組み立て（features/backup の collect を包む）
  final Future<String> Function() buildCurrentJson;

  /// バックアップ JSON の適用（features/backup の restore を包む）
  final Future<void> Function(String json) applyBackup;

  final DateTime Function() _now;

  AutoBackupRestorerImpl({
    required this.store,
    required this.buildCurrentJson,
    required this.applyBackup,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    try {
      final json = await store.read(fileName);
      if (!AutoBackupPresenter.canRestore(json)) {
        return const AutoBackupRestoreResult(
          ok: false,
          message: 'このバックアップは読み込めないか破損しています',
        );
      }

      // 復元前の現状を必ず退避（失敗したら復元しない）
      final safetyFileName = AutoBackupPolicy.fileNameFor(_now());
      final current = await buildCurrentJson();
      await store.write(safetyFileName, current);

      await applyBackup(json!);

      return AutoBackupRestoreResult(
        ok: true,
        message: 'バックアップから復元しました',
        safetyFileName: safetyFileName,
      );
    } catch (e) {
      debugPrint('[AutoBackup] restore failed ($fileName): $e');
      return AutoBackupRestoreResult(
        ok: false,
        message: '復元に失敗しました: $e',
      );
    }
  }
}
