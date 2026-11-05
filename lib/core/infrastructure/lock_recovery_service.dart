import 'app_lock_service.dart';
import 'app_lock_recovery_policy.dart';

/// ロック解除（＝ロック解除不能からの回復）の結果。
class LockRecoveryResult {
  /// 回復が成立したか（＝アプリのロックが解かれたか）。
  final bool succeeded;

  /// 入力された確認語が不正で、何も変更しなかったか。
  final bool rejected;

  /// 書き出したバックアップの識別子（パスまたはファイル名）。無ければ null。
  final String? backupPath;

  /// バックアップ取得に失敗したか（失敗しても解除は続行する）。
  final bool backupFailed;

  /// データ初期化まで完了したか。
  final bool dataWiped;

  const LockRecoveryResult({
    required this.succeeded,
    this.rejected = false,
    this.backupPath,
    this.backupFailed = false,
    this.dataWiped = false,
  });

  /// 何も変更せず拒否した結果。
  const LockRecoveryResult.reject()
      : succeeded = false,
        rejected = true,
        backupPath = null,
        backupFailed = false,
        dataWiped = false;

  @override
  String toString() => 'LockRecoveryResult(succeeded: $succeeded, '
      'rejected: $rejected, backupPath: $backupPath, '
      'backupFailed: $backupFailed, dataWiped: $dataWiped)';
}

/// パスコード忘却時の回復役。
///
/// 順序は固定：確認語の照合 → バックアップ書き出し試行 →
/// ロック解除（[AppLockService.disable]）→ データ初期化。
/// 初期化が失敗してもロック解除は済んでいるため利用者は詰まらない（fail-safe）。
/// 例外は上位へ投げない（呼び出し側は戻り値だけを見る）。
class LockRecoveryService {
  final AppLockService _service;

  /// バックアップ書き出し（戻り値はパス等の識別子。無ければ null）。
  final Future<String?> Function()? _backupExporter;

  /// データ初期化。
  final Future<void> Function()? _dataEraser;

  const LockRecoveryService(
    this._service, {
    Future<String?> Function()? backupExporter,
    Future<void> Function()? dataEraser,
  })  : _backupExporter = backupExporter,
        _dataEraser = dataEraser;

  /// 回復を実行する。
  Future<LockRecoveryResult> recover({required String confirmation}) async {
    // ① ロックが無効なら回復する意味がない。
    if (!LockRecoveryPolicy.canRecover(enabled: _service.isLocked)) {
      return const LockRecoveryResult.reject();
    }
    // ② 確認語が違えば何も変えない。
    if (!LockRecoveryPolicy.isConfirmationValid(confirmation)) {
      return const LockRecoveryResult.reject();
    }

    // ③ バックアップは「試行」に留める。失敗しても先へ進む。
    String? backupPath;
    var backupFailed = false;
    final exporter = _backupExporter;
    if (exporter != null) {
      try {
        backupPath = await exporter();
        if (backupPath == null) backupFailed = true;
      } catch (_) {
        backupFailed = true;
      }
    } else {
      backupFailed = true;
    }

    // ④ ロック解除。ここだけは失敗させない（利用者を閉じ込めない）。
    try {
      await _service.disable();
    } catch (_) {
      return LockRecoveryResult(
        succeeded: false,
        backupPath: backupPath,
        backupFailed: backupFailed,
      );
    }

    // ⑤ 初期化は失敗してもよい。失敗は呼び出し側に正直に返す。
    var dataWiped = false;
    final eraser = _dataEraser;
    if (eraser != null) {
      try {
        await eraser();
        dataWiped = true;
      } catch (_) {
        dataWiped = false;
      }
    }

    return LockRecoveryResult(
      succeeded: true,
      backupPath: backupPath,
      backupFailed: backupFailed,
      dataWiped: dataWiped,
    );
  }
}
