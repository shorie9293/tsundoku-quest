/// 自動バックアップ表示純粋ロジックの試練
///
/// 改善提案 #188 続編 — 一覧・復元・共有の導線。
/// 時刻は必ずローカル暦（DateTime.utc を固定値に使わない）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_presenter.dart';

void main() {
  group('AutoBackupPresenter.formatDate', () {
    test('ローカル暦 yyyy-MM-dd HH:mm', () {
      expect(AutoBackupPresenter.formatDate(DateTime(2026, 10, 29, 7, 12)),
          '2026-10-29 07:12');
    });

    test('1桁月日・0時0分をゼロ埋めする', () {
      expect(AutoBackupPresenter.formatDate(DateTime(2026, 1, 5)),
          '2026-01-05 00:00');
    });

    test('UTC 変換しない（ローカルの年月日時分をそのまま出す）', () {
      final local = DateTime(2026, 12, 31, 23, 59);
      expect(AutoBackupPresenter.formatDate(local), '2026-12-31 23:59');
    });
  });

  group('AutoBackupPresenter.formatSize', () {
    test('1024 未満は B 表記', () {
      expect(AutoBackupPresenter.formatSize(0), '0 B');
      expect(AutoBackupPresenter.formatSize(512), '512 B');
      expect(AutoBackupPresenter.formatSize(1023), '1023 B');
    });

    test('1024 以上は KB（小数1桁・1024基数）', () {
      expect(AutoBackupPresenter.formatSize(1024), '1.0 KB');
      expect(AutoBackupPresenter.formatSize(12700), '12.4 KB');
    });

    test('1MB 以上は MB（小数1桁）', () {
      expect(AutoBackupPresenter.formatSize(1024 * 1024), '1.0 MB');
      expect(AutoBackupPresenter.formatSize(1258291), '1.2 MB');
    });
  });

  group('AutoBackupPresenter.canRestore', () {
    test('null・空・空白は false', () {
      expect(AutoBackupPresenter.canRestore(null), isFalse);
      expect(AutoBackupPresenter.canRestore(''), isFalse);
      expect(AutoBackupPresenter.canRestore('   '), isFalse);
    });

    test('JSON パース失敗は例外を投げず false', () {
      expect(AutoBackupPresenter.canRestore('not json'), isFalse);
      expect(AutoBackupPresenter.canRestore('{"broken": '), isFalse);
    });

    test('トップが Map でなければ false', () {
      expect(AutoBackupPresenter.canRestore('[1,2,3]'), isFalse);
      expect(AutoBackupPresenter.canRestore('"string"'), isFalse);
      expect(AutoBackupPresenter.canRestore('42'), isFalse);
      expect(AutoBackupPresenter.canRestore('null'), isFalse);
    });

    test('トップが Map なら true', () {
      expect(AutoBackupPresenter.canRestore('{}'), isTrue);
      expect(AutoBackupPresenter.canRestore('{"a":1}'), isTrue);
    });
  });

  group('AutoBackupPresenter.sortNewestFirst', () {
    test('createdAt 降順・同時刻は fileName 降順', () {
      final entries = [
        AutoBackupEntry(
            fileName: 'auto_backup_20261001.json',
            createdAt: DateTime(2026, 10, 1, 9)),
        AutoBackupEntry(
            fileName: 'auto_backup_20261003.json',
            createdAt: DateTime(2026, 10, 3, 9)),
        AutoBackupEntry(
            fileName: 'auto_backup_20261002.json',
            createdAt: DateTime(2026, 10, 3, 9)),
      ];
      final sorted = AutoBackupPresenter.sortNewestFirst(entries);
      expect(sorted.map((e) => e.fileName).toList(), [
        'auto_backup_20261003.json',
        'auto_backup_20261002.json',
        'auto_backup_20261001.json',
      ]);
      // 元リストは破壊しない
      expect(entries.first.fileName, 'auto_backup_20261001.json');
    });
  });

  group('AutoBackupPresenter.retentionLabel', () {
    test('世代数と件数を出す', () {
      expect(const AutoBackupPresenter().retentionLabel(2), '保持 3世代中 2件');
      expect(
          const AutoBackupPresenter(keep: 5).retentionLabel(0), '保持 5世代中 0件');
    });
  });

  group('AutoBackupPresenter.buildRows', () {
    final entries = [
      AutoBackupEntry(
          fileName: 'manual_backup_20260901.json',
          createdAt: DateTime(2026, 9, 1, 9)),
      AutoBackupEntry(
          fileName: 'auto_backup_20261001.json',
          createdAt: DateTime(2026, 10, 1, 7, 12)),
      AutoBackupEntry(
          fileName: 'auto_backup_20261003.json',
          createdAt: DateTime(2026, 10, 3, 7, 12)),
    ];

    test('自動ファイルのみ・新しい順・世代は1始まり', () {
      final rows = const AutoBackupPresenter().buildRows(
        entries: entries,
        contents: {
          'auto_backup_20261001.json': '{"a":1}',
          'auto_backup_20261003.json': '{"b":2}',
        },
      );
      expect(rows, hasLength(2));
      expect(rows[0].entry.fileName, 'auto_backup_20261003.json');
      expect(rows[0].generation, 1);
      expect(rows[1].entry.fileName, 'auto_backup_20261001.json');
      expect(rows[1].generation, 2);
    });

    test('byteSize は UTF-8 バイト長・content null は 0', () {
      final rows = const AutoBackupPresenter().buildRows(
        entries: entries,
        contents: {
          'auto_backup_20261001.json': 'あ', // 3 bytes
          'auto_backup_20261003.json': null,
        },
      );
      // 新しい順なので 20261003 が先（content なし → 0）
      expect(rows[0].byteSize, 0);
      expect(rows[1].byteSize, 3);
      expect(rows[1].sizeLabel, '3 B');
    });

    test('restorable は canRestore の結果', () {
      final rows = const AutoBackupPresenter().buildRows(
        entries: entries,
        contents: {
          'auto_backup_20261001.json': 'broken',
          'auto_backup_20261003.json': '{"ok":true}',
        },
      );
      expect(rows[0].restorable, isTrue);
      expect(rows[1].restorable, isFalse);
    });

    test('displayLabel は 日時 / サイズ / 世代', () {
      final rows = const AutoBackupPresenter().buildRows(
        entries: [
          AutoBackupEntry(
              fileName: 'auto_backup_20261029.json',
              createdAt: DateTime(2026, 10, 29, 7, 12)),
        ],
        contents: {'auto_backup_20261029.json': 'x' * 12700},
      );
      expect(rows.single.dateLabel, '2026-10-29 07:12');
      expect(rows.single.sizeLabel, '12.4 KB');
      expect(rows.single.displayLabel, '2026-10-29 07:12 / 12.4 KB / 第1世代');
    });
  });
}
