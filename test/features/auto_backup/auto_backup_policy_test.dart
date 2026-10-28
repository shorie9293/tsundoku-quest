/// 自動バックアップ方針の試練
///
/// Kanban t_db8484e0 / 改善提案 #188 — 起動時1日1回・世代3ローテーション
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';

void main() {
  group('AutoBackupPolicy.shouldRun', () {
    const policy = AutoBackupPolicy();

    test('lastAt が null なら実行する', () {
      expect(
        policy.shouldRun(lastAt: null, now: DateTime(2026, 10, 29, 12)),
        isTrue,
      );
    });

    test('23時間59分では実行しない', () {
      final now = DateTime(2026, 10, 29, 12);
      final last = now.subtract(const Duration(hours: 23, minutes: 59));
      expect(policy.shouldRun(lastAt: last, now: now), isFalse);
    });

    test('ちょうど24時間なら実行する（境界は実行側）', () {
      final now = DateTime(2026, 10, 29, 12);
      final last = now.subtract(const Duration(hours: 24));
      expect(policy.shouldRun(lastAt: last, now: now), isTrue);
    });

    test('未来時刻でも実行する（時計巻き戻し耐性）', () {
      final now = DateTime(2026, 10, 29, 12);
      final last = now.add(const Duration(days: 3));
      expect(policy.shouldRun(lastAt: last, now: now), isTrue);
    });

    test('独自 interval を尊重する', () {
      const custom = AutoBackupPolicy(interval: Duration(hours: 6));
      final now = DateTime(2026, 10, 29, 12);
      expect(
        custom.shouldRun(
            lastAt: now.subtract(const Duration(hours: 5)), now: now),
        isFalse,
      );
      expect(
        custom.shouldRun(
            lastAt: now.subtract(const Duration(hours: 6)), now: now),
        isTrue,
      );
    });
  });

  group('AutoBackupPolicy.fileNameFor', () {
    test('ローカル暦でゼロ埋めする', () {
      expect(
        AutoBackupPolicy.fileNameFor(DateTime(2026, 1, 5)),
        'auto_backup_20260105.json',
      );
      expect(
        AutoBackupPolicy.fileNameFor(DateTime(2026, 12, 31, 23, 59)),
        'auto_backup_20261231.json',
      );
    });

    test('UTC 変換しない（深夜帯の日付がずれない）', () {
      final local = DateTime(2026, 3, 9, 1, 30);
      expect(AutoBackupPolicy.fileNameFor(local), 'auto_backup_20260309.json');
    });
  });

  group('AutoBackupPolicy.isAutoBackupFile', () {
    test('接頭辞と接尾辞の両方を満たすものだけ真', () {
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_20260105.json'),
          isTrue);
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_.json'), isTrue);
      expect(AutoBackupPolicy.isAutoBackupFile('manual_backup.json'), isFalse);
      expect(AutoBackupPolicy.isAutoBackupFile('auto_backup_20260105.txt'),
          isFalse);
      expect(AutoBackupPolicy.isAutoBackupFile('20260105_auto_backup.json'),
          isFalse);
    });
  });

  group('AutoBackupPolicy.latestCreatedAt', () {
    test('空なら null', () {
      expect(const AutoBackupPolicy().latestCreatedAt(const []), isNull);
    });

    test('手動ファイルは無視し自動ファイルの最大を返す', () {
      final entries = [
        AutoBackupEntry(
            fileName: 'manual_20991231.json', createdAt: DateTime(2099, 12, 31)),
        AutoBackupEntry(
            fileName: 'auto_backup_20260101.json',
            createdAt: DateTime(2026, 1, 1)),
        AutoBackupEntry(
            fileName: 'auto_backup_20260105.json',
            createdAt: DateTime(2026, 1, 5)),
      ];
      expect(
        const AutoBackupPolicy().latestCreatedAt(entries),
        DateTime(2026, 1, 5),
      );
    });

    test('自動ファイルが無ければ null', () {
      final entries = [
        AutoBackupEntry(
            fileName: 'manual.json', createdAt: DateTime(2026, 1, 1)),
      ];
      expect(const AutoBackupPolicy().latestCreatedAt(entries), isNull);
    });
  });

  group('AutoBackupPolicy.prune', () {
    AutoBackupEntry auto(String day) => AutoBackupEntry(
          fileName: 'auto_backup_202601$day.json',
          createdAt: DateTime(2026, 1, int.parse(day)),
        );

    test('keep=3 で最古の1件のみ削除対象', () {
      final entries = [auto('01'), auto('02'), auto('03'), auto('04')];
      final pruned = const AutoBackupPolicy().prune(entries);
      expect(pruned.map((e) => e.fileName),
          ['auto_backup_20260101.json']);
    });

    test('順序が逆でも新しい3件を残す', () {
      final entries = [auto('03'), auto('01'), auto('04'), auto('02')];
      final pruned = const AutoBackupPolicy().prune(entries);
      expect(pruned.map((e) => e.fileName),
          ['auto_backup_20260101.json']);
    });

    test('keep 以下なら削除対象なし', () {
      expect(
        const AutoBackupPolicy().prune([auto('01'), auto('02'), auto('03')]),
        isEmpty,
      );
    });

    test('手動ファイルは絶対に削除対象へ含めない', () {
      final entries = [
        AutoBackupEntry(
            fileName: 'manual_old.json', createdAt: DateTime(2000, 1, 1)),
        auto('01'),
        auto('02'),
        auto('03'),
        auto('04'),
      ];
      final pruned = const AutoBackupPolicy().prune(entries);
      expect(pruned.map((e) => e.fileName), ['auto_backup_20260101.json']);
    });

    test('同時刻は fileName 降順で安定に決まる', () {
      final same = DateTime(2026, 1, 1);
      final entries = [
        AutoBackupEntry(fileName: 'auto_backup_a.json', createdAt: same),
        AutoBackupEntry(fileName: 'auto_backup_b.json', createdAt: same),
        AutoBackupEntry(fileName: 'auto_backup_c.json', createdAt: same),
        AutoBackupEntry(fileName: 'auto_backup_d.json', createdAt: same),
      ];
      final pruned = const AutoBackupPolicy().prune(entries);
      expect(pruned.map((e) => e.fileName), ['auto_backup_a.json']);
    });
  });
}
