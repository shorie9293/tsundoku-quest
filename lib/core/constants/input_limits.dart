/// 入力欄の長さ上限（意味に応じた値）。
///
/// 方針:
/// - カウンタ表示によるレイアウト変化を避けるため、`maxLength:` ではなく
///   `LengthLimitingTextInputFormatter` にこれらの値を渡す。
/// - 数値欄は「桁数」で上限を決める（全角数字→半角変換は入力後に走るため、
///   全角1文字=1桁として数えても破綻しない桁数にしている）。
/// - 保存系の欄は、保存先のドメイン上限（例: [QuickMemoDraft.maxLength]）と
///   揃え、切り詰めでデータが壊れないようにする。
abstract final class InputLimits {
  const InputLimits._();

  // ── 照合・確認 ─────────────────────────────
  /// アプリロック解除の確認語（3文字）に余裕を持たせた上限。
  static const int appLockRecoveryConfirm = 12;

  /// アカウント削除の確認語（2文字）に余裕を持たせた上限。
  static const int accountDeletionConfirm = 32;

  // ── バックアップ ───────────────────────────
  /// バックアップJSON貼付欄。JSON全体を受けるため十分大きく取り、
  /// 切り詰めによる復元不能を起こさない。
  static const int backupJsonImport = 100000;

  // ── 検索 ─────────────────────────────────
  /// 書名・著者などの検索語。
  static const int searchQuery = 100;

  // ── 書誌情報 ───────────────────────────────
  /// 手動登録のタイトル。
  static const int bookTitle = 200;

  /// 手動登録の著者（カンマ区切りで複数名）。
  static const int bookAuthor = 100;

  /// ISBN（ハイフン付き13桁＋α）。
  static const int isbn = 20;

  /// 読書メモ（1冊あたりのメモ）。
  static const int bookNotes = 2000;

  /// クイックメモ。ドメイン側の上限と一致させ、無言の切り詰めを防ぐ。
  static const int quickMemo = 2000;

  /// 戦利品カードの学び・行動・引用（1項目あたり）。
  static const int trophyEntry = 500;

  // ── 数値（桁数） ───────────────────────────
  /// 1日の目標（分）。9999分まで。
  static const int dailyGoalMinutesDigits = 4;

  /// 月間・年間の読了目標（冊）。999冊まで。
  static const int readingGoalBooksDigits = 3;

  /// 読書セッションの読書時間（分）。9999分まで。
  static const int sessionMinutesDigits = 4;

  /// ページ番号。999999ページまで。
  static const int pageNumberDigits = 6;
}
