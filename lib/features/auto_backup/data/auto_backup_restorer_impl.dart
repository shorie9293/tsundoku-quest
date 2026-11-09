/// 自動バックアップの復元実装
///
/// Kanban t_db8484e0 / 改善提案 #188 続編。
/// 手順は固定：read → canRestore 検証 → **現状スナップショットの強制保存**
/// → 既存インポート経路（features/backup）で適用。
/// 例外はすべて捕まえて ok:false に落とす（UI を壊さない）。
///
/// 設定つき復元（[AutoBackupRestorerWithOptions]）:
/// - `includeSettings:false` なら設定を触らない経路へ委ねる。
/// - 設定適用後は [onSettingsRestored] を投げっぱなしで呼ぶ
///   （通知の再予約。失敗しても復元結果は ok のまま）。
library;

import 'dart:async';

import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_presenter.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:tsundoku_quest/core/logging/app_logger.dart';

/// 自動バックアップからの復元
class AutoBackupRestorerImpl implements AutoBackupRestorerWithOptions {
  /// 保管庫
  final AutoBackupStore store;

  /// 現状 JSON の組み立て（features/backup の collect を包む）
  final Future<String> Function() buildCurrentJson;

  /// バックアップ JSON の適用（features/backup の restore を包む）
  final Future<void> Function(String json) applyBackup;

  /// 復元オプション付きの適用（設定を戻すかどうかを下流へ渡す）。
  /// null なら [applyBackup] に落ちる（後方互換）。
  final Future<void> Function(String json, bool includeSettings)?
      applyBackupWithOptions;

  /// 設定適用成功後に呼ぶ後処理（通知の再予約など）。
  /// 投げっぱなし・例外握りで呼ぶ（復元結果を変えない）。
  final Future<void> Function()? onSettingsRestored;

  final DateTime Function() _now;

  AutoBackupRestorerImpl({
    required this.store,
    required this.buildCurrentJson,
    required this.applyBackup,
    this.applyBackupWithOptions,
    this.onSettingsRestored,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) =>
      restoreWithOptions(fileName);

  @override
  Future<AutoBackupRestoreResult> restoreWithOptions(
    String fileName, {
    bool includeSettings = true,
  }) async {
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

      final withOptions = applyBackupWithOptions;
      if (withOptions != null) {
        await withOptions(json!, includeSettings);
      } else {
        await applyBackup(json!);
      }

      if (includeSettings) {
        _rescheduleNotifications();
      }

      return AutoBackupRestoreResult(
        ok: true,
        message:
            includeSettings ? 'バックアップから復元しました' : 'バックアップから復元しました（設定は変更していません）',
        safetyFileName: safetyFileName,
      );
    } catch (e) {
      appLog.warn('[AutoBackup] restore failed ($fileName): $e');
      return AutoBackupRestoreResult(
        ok: false,
        message: '復元に失敗しました: $e',
      );
    }
  }

  /// 通知の再予約（設定が戻った後に呼ぶ）。投げっぱなし＋例外握り。
  void _rescheduleNotifications() {
    final callback = onSettingsRestored;
    if (callback == null) return;
    unawaited(
      Future<void>(() async {
        try {
          await callback();
        } catch (e) {
          appLog.warn('[AutoBackup] settings post-process failed: $e');
        }
      }),
    );
  }
}
