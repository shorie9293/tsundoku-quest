/// 起動時自動バックアップの配線（投げっぱなし）
///
/// Kanban t_db8484e0 / 改善提案 #188 — 全現世共通仕様
/// 起動処理をブロックせず、例外は debugPrint に留める。
library;

import 'dart:async';

import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_service.dart';
import 'package:tsundoku_quest/core/logging/app_logger.dart';

/// 起動時に1回だけ自動バックアップを予約する（await しない）。
void scheduleAutoBackup({
  required Future<String> Function() buildJson,
  AutoBackupStore? store,
  AutoBackupPolicy policy = const AutoBackupPolicy(),
  AutoBackupStatusStore? statusStore,
}) {
  try {
    final service = AutoBackupService(
      store: store ?? FileAutoBackupStore(),
      policy: policy,
      statusStore: statusStore ?? FileAutoBackupStatusStore(),
    );
    unawaited(
      service.run(buildJson).then((result) {
        if (result.ran) {
          appLog.debug('[AutoBackup] 書き込み完了: ${result.fileName}'
              '${result.pruned.isEmpty ? '' : ' / 整理: ${result.pruned.join(', ')}'}');
        } else if (result.error != null) {
          appLog.warn('[AutoBackup] 失敗（起動は継続）: ${result.error}');
        } else {
          appLog.debug('[AutoBackup] スキップ（24時間未経過）');
        }
      }).catchError((Object e, StackTrace st) {
        appLog.warn('[AutoBackup] 想定外の失敗（起動は継続）: $e\n$st');
      }),
    );
  } catch (e) {
    appLog.warn('[AutoBackup] 起動時の配線失敗（起動は継続）: $e');
  }
}
