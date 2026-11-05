/// ロック解除手段を失った場合の回復方針（純粋ロジック）
///
/// パスコード忘却時の唯一の出口。誤操作でデータを失わないよう
/// 「確認語の一致」を必須とし、文言はここに一箇所だけ置く。
library;

/// 回復（データ初期化）の確認語。
const String kLockRecoveryConfirmationPhrase = '初期化';

/// 回復方針。
class LockRecoveryPolicy {
  const LockRecoveryPolicy._();

  /// 確認語（利用者に手入力させる）。
  static String get confirmationPhrase => kLockRecoveryConfirmationPhrase;

  /// ダイアログに出す警告文。
  static const String warningMessage =
      '続行するとロックを解除したうえで、この端末の読書データ・設定をすべて初期化します。'
      '元に戻せません（自動バックアップが書き出せる場合は先に書き出します）。';

  /// 回復が意味を持つ状況か。ロックが無効なら回復不要。
  static bool canRecover({required bool enabled}) => enabled;

  /// 入力された確認語が正しいか。前後の空白は無視する。
  static bool isConfirmationValid(String input) =>
      input.trim() == kLockRecoveryConfirmationPhrase;
}
