/// 自動バックアップからの復元契約
///
/// Kanban t_db8484e0 / 改善提案 #188 続編。
/// 実装は「復元前スナップショットの強制保存」を必ず行う（data 層）。
library;

/// 復元結果
class AutoBackupRestoreResult {
  /// 成否
  final bool ok;

  /// 利用者向けのメッセージ（失敗理由を含む）
  final String? message;

  /// 復元前に書いた現状スナップショットのファイル名
  final String? safetyFileName;

  const AutoBackupRestoreResult({
    required this.ok,
    this.message,
    this.safetyFileName,
  });

  @override
  String toString() =>
      'AutoBackupRestoreResult(ok: $ok, message: $message, safety: $safetyFileName)';
}

/// 復元役
abstract interface class AutoBackupRestorer {
  /// [fileName] のバックアップを適用する（例外は投げない）
  Future<AutoBackupRestoreResult> restore(String fileName);
}

/// 復元オプション付きの復元役
///
/// [AutoBackupRestorer] を実装した上で、復元時に「設定も戻すか」を選べる。
/// 既存のフェイク（[AutoBackupRestorer] のみ実装）を全滅させないための
/// **追加インタフェース**であり、画面は `is` 判定で新経路へ分岐する。
abstract interface class AutoBackupRestorerWithOptions
    implements AutoBackupRestorer {
  /// [fileName] のバックアップを適用する。
  ///
  /// [includeSettings] が false なら記録（蔵書・セッション・目標）だけ戻し、
  /// 設定（テーマ・文字サイズ・静穏時間・リマインダー等）は触らない。
  Future<AutoBackupRestoreResult> restoreWithOptions(
    String fileName, {
    bool includeSettings = true,
  });
}
