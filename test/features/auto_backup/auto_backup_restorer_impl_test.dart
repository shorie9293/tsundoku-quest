/// 自動バックアップ復元アダプタの試練
///
/// 改善提案 #188 続編。復元前スナップショットの順序と例外非波及を検証する。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_restorer_impl.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_restorer.dart';

void main() {
  group('AutoBackupRestorerImpl', () {
    late InMemoryAutoBackupStore store;
    late DateTime now;
    late List<String> ops;
    late List<String> applied;

    setUp(() async {
      now = DateTime(2026, 10, 29, 9, 30); // ローカル暦
      ops = [];
      applied = [];
      store = InMemoryAutoBackupStore(now: () => now);
      await store.write('auto_backup_20261028.json', '{"day":28}');
      ops.clear();
    });

    AutoBackupRestorerImpl build({bool applyFails = false}) =>
        AutoBackupRestorerImpl(
          store: store,
          now: () => now,
          buildCurrentJson: () async {
            ops.add('build');
            return '{"current":true}';
          },
          applyBackup: (json) async {
            ops.add('apply');
            if (applyFails) throw StateError('apply failed');
            applied.add(json);
          },
        );

    test('復元前に本日分スナップショットを強制保存する（write→apply の順）', () async {
      final restorer = build();

      final result = await restorer.restore('auto_backup_20261028.json');

      expect(result.ok, isTrue);
      expect(result.safetyFileName, 'auto_backup_20261029.json');
      expect(ops, ['build', 'apply']);
      expect(store.contentOf('auto_backup_20261029.json'), '{"current":true}');
      expect(applied, ['{"day":28}']);
      // 復元対象は消さない
      expect(store.contentOf('auto_backup_20261028.json'), '{"day":28}');
    });

    test('不正 JSON は適用せず、スナップショットも書かない', () async {
      await store.write('auto_backup_20261027.json', 'not json');
      final restorer = build();

      final result = await restorer.restore('auto_backup_20261027.json');

      expect(result.ok, isFalse);
      expect(result.message, isNotNull);
      expect(applied, isEmpty);
      expect(store.contentOf('auto_backup_20261029.json'), isNull);
    });

    test('存在しないファイルは ok:false（例外を投げない）', () async {
      final result = await build().restore('auto_backup_20990101.json');

      expect(result.ok, isFalse);
      expect(applied, isEmpty);
    });

    test('apply が例外を投げても捕捉して ok:false（例外非波及）', () async {
      final restorer = build(applyFails: true);

      late AutoBackupRestoreResult result;
      result = await restorer.restore('auto_backup_20261028.json');

      expect(result.ok, isFalse);
      expect(result.message, contains('apply failed'));
      // 現状スナップショットは先に保存済み
      expect(store.contentOf('auto_backup_20261029.json'), '{"current":true}');
    });

    test('スナップショット保存が失敗しても throw しない', () async {
      final failingStore = _WriteFailingStore();
      final restorer = AutoBackupRestorerImpl(
        store: failingStore,
        now: () => now,
        buildCurrentJson: () async => '{"current":true}',
        applyBackup: (json) async => applied.add(json),
      );

      final result = await restorer.restore('auto_backup_20261028.json');

      expect(result.ok, isFalse);
      expect(applied, isEmpty);
    });
  });
}

/// write だけ失敗する保管庫
class _WriteFailingStore implements AutoBackupStore {
  final Map<String, String> _contents = {
    'auto_backup_20261028.json': '{"day":28}',
  };

  @override
  Future<List<AutoBackupEntry>> list() async => [
        AutoBackupEntry(
          fileName: 'auto_backup_20261028.json',
          createdAt: DateTime(2026, 10, 28, 9),
        ),
      ];

  @override
  Future<String?> read(String fileName) async => _contents[fileName];

  @override
  Future<void> write(String fileName, String contents) async =>
      throw StateError('write failed');

  @override
  Future<void> delete(String fileName) async {}
}
