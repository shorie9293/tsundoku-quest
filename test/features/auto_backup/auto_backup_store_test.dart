/// 自動バックアップ保管庫の試練
///
/// Kanban t_db8484e0 / 改善提案 #188
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';

void main() {
  group('InMemoryAutoBackupStore', () {
    test('同日同名書き込みは上書きで冪等（1件のまま）', () async {
      var now = DateTime(2026, 10, 29, 9);
      final store = InMemoryAutoBackupStore(now: () => now);
      const name = 'auto_backup_20261029.json';

      await store.write(name, '{"v":1}');
      now = DateTime(2026, 10, 29, 21);
      await store.write(name, '{"v":2}');

      final entries = await store.list();
      expect(entries, hasLength(1));
      expect(entries.single.fileName, name);
      expect(store.contentOf(name), '{"v":2}');
    });

    test('delete で消える', () async {
      final store = InMemoryAutoBackupStore();
      await store.write('auto_backup_20260101.json', '{}');
      await store.write('auto_backup_20260102.json', '{}');

      await store.delete('auto_backup_20260101.json');

      final names = (await store.list()).map((e) => e.fileName).toList();
      expect(names, ['auto_backup_20260102.json']);
    });

    test('list は書き込み時刻を createdAt に持つ', () async {
      final now = DateTime(2026, 10, 29, 8, 15);
      final store = InMemoryAutoBackupStore(now: () => now);
      await store.write('auto_backup_20261029.json', '{}');

      expect((await store.list()).single.createdAt, now);
    });

    test('read は書き込み内容を往復し、未存在は null', () async {
      final store = InMemoryAutoBackupStore();
      await store.write('auto_backup_20261029.json', '{"v":1}');

      expect(await store.read('auto_backup_20261029.json'), '{"v":1}');
      expect(await store.read('auto_backup_20990101.json'), isNull);
    });
  });

  group('FileAutoBackupStore', () {
    late Directory tempDir;
    late FileAutoBackupStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('auto_backup_test_');
      store = FileAutoBackupStore(directoryResolver: () async => tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('list は自動バックアップ命名のファイルのみ返す', () async {
      await store.write('auto_backup_20260101.json', '{"a":1}');
      await store.write('auto_backup_20260102.json', '{"a":2}');

      final backupDir = Directory('${tempDir.path}/auto_backups');
      await File('${backupDir.path}/manual_backup.json').writeAsString('{}');
      await File('${backupDir.path}/auto_backup_note.txt').writeAsString('x');

      final names = (await store.list()).map((e) => e.fileName).toList()
        ..sort();
      expect(names, ['auto_backup_20260101.json', 'auto_backup_20260102.json']);
    });

    test('書き込み内容を読み戻せる（auto_backups 配下・冪等上書き）', () async {
      await store.write('auto_backup_20260101.json', '{"v":1}');
      await store.write('auto_backup_20260101.json', '{"v":2}');

      final file =
          File('${tempDir.path}/auto_backups/auto_backup_20260101.json');
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), '{"v":2}');
    });

    test('createdAt は FileStat.modified を採用する', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 2));
      await store.write('auto_backup_20260101.json', '{}');

      final entry = (await store.list()).single;
      expect(entry.createdAt.isBefore(before), isFalse);
      expect(AutoBackupPolicy.isAutoBackupFile(entry.fileName), isTrue);
    });

    test('delete でファイルが消える', () async {
      await store.write('auto_backup_20260101.json', '{}');
      await store.delete('auto_backup_20260101.json');

      expect(await store.list(), isEmpty);
      expect(
        await File('${tempDir.path}/auto_backups/auto_backup_20260101.json')
            .exists(),
        isFalse,
      );
    });

    test('read は内容を往復し、未存在は null（例外を投げない）', () async {
      await store.write('auto_backup_20260101.json', '{"v":7}');

      expect(await store.read('auto_backup_20260101.json'), '{"v":7}');
      expect(await store.read('auto_backup_20991231.json'), isNull);
    });
  });
}
