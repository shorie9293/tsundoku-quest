/// 自動バックアップの共有契約
///
/// Kanban t_db8484e0 / 改善提案 #188 続編。
/// アプリ専用領域に閉じ込めず、利用者が取り出せる導線を担う。
library;

/// 共有役（未注入なら UI に導線を出さない）
abstract interface class AutoBackupSharer {
  /// [fileName] の [json] を共有する
  Future<void> share(String fileName, String json);
}
