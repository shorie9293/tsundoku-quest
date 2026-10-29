/// 自動バックアップ一覧の表示ロジック（純粋・I/O なし）
///
/// Kanban t_db8484e0 / 改善提案 #188 続編 — 閲覧・復元・共有の導線。
/// 日時は必ずローカル暦で表す（UTC 変換禁止）。
/// JSON 判定は例外を投げず false に落とす。
library;

import 'dart:convert';

import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';

/// 一覧1行分の表示データ
class AutoBackupRow {
  /// 元エントリ（fileName / createdAt）
  final AutoBackupEntry entry;

  /// UTF-8 バイト長
  final int byteSize;

  /// 新しい順の1始まり世代番号
  final int generation;

  /// 復元可能な JSON か
  final bool restorable;

  const AutoBackupRow({
    required this.entry,
    required this.byteSize,
    required this.generation,
    required this.restorable,
  });

  /// ローカル暦 yyyy-MM-dd HH:mm
  String get dateLabel => AutoBackupPresenter.formatDate(entry.createdAt);

  /// 512 B / 12.4 KB / 1.2 MB
  String get sizeLabel => AutoBackupPresenter.formatSize(byteSize);

  /// 2026-10-29 07:12 / 12.4 KB / 第1世代
  String get displayLabel => '$dateLabel / $sizeLabel / 第$generation世代';
}

/// 表示文字列と並びの決定
class AutoBackupPresenter {
  /// 保持世代数（保持ラベル用）
  final int keep;

  const AutoBackupPresenter({this.keep = AutoBackupPolicy.defaultKeep});

  /// ローカル暦 yyyy-MM-dd HH:mm（UTC 変換しない）
  static String formatDate(DateTime at) {
    final y = at.year.toString().padLeft(4, '0');
    final mo = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    final h = at.hour.toString().padLeft(2, '0');
    final mi = at.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  /// 1024 基数・小数1桁（1024 未満は B）
  static String formatSize(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes < kb) return '$bytes B';
    final k = bytes / kb;
    if (bytes < mb) return '${k.toStringAsFixed(1)} KB';
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }

  /// 復元可能な JSON か（例外を絶対に投げない）
  static bool canRestore(String? json) {
    if (json == null) return false;
    final trimmed = json.trim();
    if (trimmed.isEmpty) return false;
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map;
    } catch (_) {
      return false;
    }
  }

  /// createdAt 降順 → fileName 降順（元リストは破壊しない）
  static List<AutoBackupEntry> sortNewestFirst(List<AutoBackupEntry> entries) {
    final sorted = List<AutoBackupEntry>.of(entries);
    sorted.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      if (byTime != 0) return byTime;
      return b.fileName.compareTo(a.fileName);
    });
    return sorted;
  }

  /// '保持 3世代中 2件'
  String retentionLabel(int count) => '保持 $keep世代中 $count件';

  /// 自動バックアップのみを新しい順に取り出して行データにする
  List<AutoBackupRow> buildRows({
    required List<AutoBackupEntry> entries,
    required Map<String, String?> contents,
  }) {
    final auto = sortNewestFirst(
      entries
          .where((e) => AutoBackupPolicy.isAutoBackupFile(e.fileName))
          .toList(),
    );
    final rows = <AutoBackupRow>[];
    for (var i = 0; i < auto.length; i++) {
      final entry = auto[i];
      final content = contents[entry.fileName];
      rows.add(AutoBackupRow(
        entry: entry,
        byteSize: content == null ? 0 : utf8.encode(content).length,
        generation: i + 1,
        restorable: canRestore(content),
      ));
    }
    return rows;
  }
}
