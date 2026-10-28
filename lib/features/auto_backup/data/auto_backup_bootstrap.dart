/// 起動時自動バックアップの配線（投げっぱなし）
///
/// Kanban t_db8484e0 / 改善提案 #188 — 全現世共通仕様
/// 起動処理をブロックせず、例外は debugPrint に留める。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_service.dart';

/// 起動時に1回だけ自動バックアップを予約する（await しない）。
void scheduleAutoBackup({
  required Future<String> Function() buildJson,
  AutoBackupStore? store,
  AutoBackupPolicy policy = const AutoBackupPolicy(),
}) {
  try {
    final service = AutoBackupService(
      store: store ?? FileAutoBackupStore(),
      policy: policy,
    );
    unawaited(
      service.run(buildJson).then((result) {
        if (result.ran) {
          debugPrint('[AutoBackup] 書き込み完了: ${result.fileName}'
              '${result.pruned.isEmpty ? '' : ' / 整理: ${result.pruned.join(', ')}'}');
        } else if (result.error != null) {
          debugPrint('[AutoBackup] 失敗（起動は継続）: ${result.error}');
        } else {
          debugPrint('[AutoBackup] スキップ（24時間未経過）');
        }
      }).catchError((Object e, StackTrace st) {
        debugPrint('[AutoBackup] 想定外の失敗（起動は継続）: $e\n$st');
      }),
    );
  } catch (e) {
    debugPrint('[AutoBackup] 起動時の配線失敗（起動は継続）: $e');
  }
}
