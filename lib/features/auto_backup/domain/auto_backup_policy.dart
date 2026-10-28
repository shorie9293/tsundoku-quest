/// 自動バックアップ方針（純粋ロジック）
///
/// Kanban t_db8484e0 / 改善提案 #188 — 全現世共通仕様
/// 起動時1日1回・世代3ローテーションの判断だけを担い、IO には触れない。
library;

/// バックアップ保管庫上の1エントリ
class AutoBackupEntry {
  /// ファイル名（例: auto_backup_20261029.json）
  final String fileName;

  /// 生成時刻（保管庫の書き込み時刻／FileStat.modified）
  final DateTime createdAt;

  const AutoBackupEntry({required this.fileName, required this.createdAt});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoBackupEntry &&
          other.fileName == fileName &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(fileName, createdAt);

  @override
  String toString() => 'AutoBackupEntry($fileName, $createdAt)';
}

/// 実行可否・命名・世代整理の規則
class AutoBackupPolicy {
  /// 既定の保持世代数
  static const int defaultKeep = 3;

  /// 既定の実行間隔（起動時1日1回）
  static const Duration defaultInterval = Duration(hours: 24);

  /// 自動バックアップの接頭辞
  static const String filePrefix = 'auto_backup_';

  /// 自動バックアップの接尾辞
  static const String fileSuffix = '.json';

  /// 実行間隔
  final Duration interval;

  /// 保持世代数
  final int keep;

  const AutoBackupPolicy({
    this.interval = defaultInterval,
    this.keep = defaultKeep,
  });

  /// 実行すべきか。
  ///
  /// - [lastAt] が null（初回）なら true
  /// - 経過が [interval] 以上なら true（ちょうど24時間は実行）
  /// - 未来時刻（時計巻き戻し）でも true
  bool shouldRun({DateTime? lastAt, required DateTime now}) {
    if (lastAt == null) return true;
    final elapsed = now.difference(lastAt);
    if (elapsed.isNegative) return true;
    return elapsed >= interval;
  }

  /// ローカル暦の日付からファイル名を組み立てる（UTC 変換禁止）
  static String fileNameFor(DateTime now) {
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$filePrefix$y$m$d$fileSuffix';
  }

  /// 自動バックアップ命名か
  static bool isAutoBackupFile(String name) =>
      name.startsWith(filePrefix) && name.endsWith(fileSuffix);

  /// 自動ファイルのみを新しい順（createdAt 降順・同値は fileName 降順）に並べる
  static List<AutoBackupEntry> _sortedAuto(List<AutoBackupEntry> entries) {
    final auto = entries.where((e) => isAutoBackupFile(e.fileName)).toList();
    auto.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      if (byTime != 0) return byTime;
      return b.fileName.compareTo(a.fileName);
    });
    return auto;
  }

  /// 直近の自動バックアップ生成時刻（無ければ null）
  DateTime? latestCreatedAt(List<AutoBackupEntry> entries) {
    final sorted = _sortedAuto(entries);
    return sorted.isEmpty ? null : sorted.first.createdAt;
  }

  /// 保持世代を超えた削除対象を返す（手動ファイルは絶対に返さない）
  List<AutoBackupEntry> prune(List<AutoBackupEntry> entries) {
    final sorted = _sortedAuto(entries);
    if (sorted.length <= keep) return const [];
    return sorted.sublist(keep < 0 ? 0 : keep);
  }
}
