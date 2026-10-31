import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/crash/crash_log_entry.dart';
import 'package:tsundoku_quest/core/crash/crash_log_repository.dart';

CrashLogEntry _entry(int i) => CrashLogEntry(
      timestamp: DateTime.utc(2026, 11, 1, 0, 0).add(Duration(minutes: i)),
      kind: 'error',
      message: 'error_$i',
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('crash_log_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('FileCrashLogRepository', () {
    FileCrashLogRepository buildRepo() => FileCrashLogRepository(
          file: File('${tempDir.path}/crash_log.jsonl'),
        );

    test('append で1行増える（JSONL・1行1件）', () async {
      final repo = buildRepo();
      expect(await repo.loadAll(), isEmpty);

      await repo.append(_entry(0));

      final file = File('${tempDir.path}/crash_log.jsonl');
      final lines = await file.readAsLines();
      expect(lines.where((l) => l.trim().isNotEmpty).length, 1);
      final loaded = await repo.loadAll();
      expect(loaded.length, 1);
      expect(loaded.single.message, 'error_0');
    });

    test('51件目で最古が落ちて50件になる', () async {
      final repo = buildRepo();
      for (var i = 0; i < 51; i++) {
        await repo.append(_entry(i));
      }
      final loaded = await repo.loadAll();
      expect(loaded.length, kCrashLogMaxEntries);
      expect(loaded.first.message, 'error_1');
      expect(loaded.last.message, 'error_50');
    });

    test('壊れた行は読み飛ばす', () async {
      final file = File('${tempDir.path}/crash_log.jsonl');
      await file.writeAsString(
        '${_entry(0).toJsonLine()}\n'
        '{ this is not json\n'
        '\n'
        '{"ts":"nope","kind":"error","message":"m"}\n'
        '${_entry(1).toJsonLine()}\n',
      );

      final loaded = await buildRepo().loadAll();
      expect(loaded.length, 2);
      expect(loaded.map((e) => e.message), ['error_0', 'error_1']);
    });

    test('clear で空になる', () async {
      final repo = buildRepo();
      await repo.append(_entry(0));
      await repo.clear();
      expect(await repo.loadAll(), isEmpty);
    });

    test('書き込み失敗は握る（例外を投げない）', () async {
      // ディレクトリをファイルパスとして渡すと書き込みが失敗する
      final repo = FileCrashLogRepository(file: File(tempDir.path));
      await expectLater(repo.append(_entry(0)), completes);
    });
  });

  group('InMemoryCrashLogRepository', () {
    test('同じローテート規則（直近50件）', () async {
      final repo = InMemoryCrashLogRepository();
      for (var i = 0; i < 51; i++) {
        await repo.append(_entry(i));
      }
      final loaded = await repo.loadAll();
      expect(loaded.length, kCrashLogMaxEntries);
      expect(loaded.first.message, 'error_1');
    });
  });
}
