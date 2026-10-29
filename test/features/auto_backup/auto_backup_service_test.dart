/// 自動バックアップ実行役と起動配線の試練
///
/// Kanban t_db8484e0 / 改善提案 #188
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_bootstrap.dart';
import 'package:tsundoku_quest/features/auto_backup/data/auto_backup_store.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:tsundoku_quest/features/auto_backup/domain/auto_backup_service.dart';

/// list が必ず失敗する保管庫（例外握りの検証用）
class _FailingStore implements AutoBackupStore {
  @override
  Future<List<AutoBackupEntry>> list() async => throw StateError('list failed');

  @override
  Future<void> write(String fileName, String contents) async {}

  @override
  Future<String?> read(String fileName) async => null;

  @override
  Future<void> delete(String fileName) async {}
}

void main() {
  const policy = AutoBackupPolicy();
  late DateTime now;
  late InMemoryAutoBackupStore store;
  late AutoBackupService service;
  var calls = 0;
  var failing = false;

  Future<String> build() async {
    calls++;
    if (failing) throw const FormatException('build failed');
    return '{"generatedAt":"${now.toIso8601String()}"}';
  }

  setUp(() {
    now = DateTime(2026, 10, 29, 9);
    store = InMemoryAutoBackupStore(now: () => now);
    service = AutoBackupService(store: store, policy: policy, now: () => now);
    calls = 0;
    failing = false;
  });

  group('AutoBackupService.run', () {
    test('初回は書き込みを実行し ran:true を返す', () async {
      final result = await service.run(build);

      expect(result.ran, isTrue);
      expect(result.error, isNull);
      expect(result.fileName, 'auto_backup_20261029.json');
      expect(result.pruned, isEmpty);
      expect((await store.list()).single.fileName, 'auto_backup_20261029.json');
      expect(calls, 1);
    });

    test('24時間未満ならスキップし buildJson を呼ばない', () async {
      now = DateTime(2026, 10, 28, 9, 30);
      await store.write('auto_backup_20261028.json', '{}');

      now = DateTime(2026, 10, 29, 9);
      final result = await service.run(build);

      expect(result.ran, isFalse);
      expect(result.fileName, isNull);
      expect(result.error, isNull);
      expect(calls, 0);
      expect(await store.list(), hasLength(1));
    });

    test('4件目を書いたら最古1件を削除し pruned に載せる', () async {
      for (final day in [26, 27, 28]) {
        now = DateTime(2026, 10, day, 9);
        await store.write('auto_backup_202610$day.json', '{}');
      }

      now = DateTime(2026, 10, 29, 9);
      final result = await service.run(build);

      expect(result.ran, isTrue);
      expect(result.pruned, ['auto_backup_20261026.json']);
      final names = (await store.list()).map((e) => e.fileName).toList();
      expect(names, hasLength(3));
      expect(names.contains('auto_backup_20261026.json'), isFalse);
    });

    test('buildJson の例外を握って ran:false + error を返す', () async {
      failing = true;
      final result = await service.run(build);

      expect(result.ran, isFalse);
      expect(result.error, isA<FormatException>());
      expect(await store.list(), isEmpty);
    });

    test('保管庫の例外も握って ran:false + error を返す', () async {
      final svc = AutoBackupService(store: _FailingStore(), policy: policy);
      final result = await svc.run(build);

      expect(result.ran, isFalse);
      expect(result.error, isA<StateError>());
    });

    test('同日再実行は同名上書きで冪等（1件のまま）', () async {
      // interval を 0 にして上書き経路を通す（既定24hならスキップされる）
      final svc = AutoBackupService(
        store: store,
        policy: const AutoBackupPolicy(interval: Duration.zero),
        now: () => now,
      );
      await svc.run(build);
      now = DateTime(2026, 10, 29, 23, 45);
      final second = await svc.run(build);

      expect(second.ran, isTrue);
      final entries = await store.list();
      expect(entries, hasLength(1));
      expect(store.contentOf('auto_backup_20261029.json'),
          contains('2026-10-29T23:45'));
    });

    test('既定24h方針では同日2回目をスキップする', () async {
      await service.run(build);
      now = DateTime(2026, 10, 29, 23, 45);
      final second = await service.run(build);

      expect(second.ran, isFalse);
      expect(await store.list(), hasLength(1));
    });
  });

  group('scheduleAutoBackup', () {
    test('例外を外へ伝播せず、失敗時も落ちない', () async {
      failing = true;
      scheduleAutoBackup(
        buildJson: build,
        store: store,
        policy: policy,
      );

      await pumpEventQueue();
      expect(await store.list(), isEmpty);
    });

    test('成功時は投げっぱなしでも保管庫へ書き込まれる', () async {
      scheduleAutoBackup(
        buildJson: build,
        store: store,
        policy: policy,
      );

      await pumpEventQueue();
      final entries = await store.list();
      expect(entries, hasLength(1));
      expect(
          AutoBackupPolicy.isAutoBackupFile(entries.single.fileName), isTrue);
    });
  });
}
