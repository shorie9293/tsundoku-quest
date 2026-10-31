import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/core/crash/crash_log_entry.dart';
import 'package:tsundoku_quest/core/crash/crash_log_repository.dart';
import 'package:tsundoku_quest/core/crash/crash_log_service.dart';

CrashLogEntry _at(DateTime ts, String message) => CrashLogEntry(
      timestamp: ts,
      kind: 'error',
      message: message,
    );

void main() {
  group('CrashLogger', () {
    test('record で1行増える（例外を投げない）', () async {
      final repo = InMemoryCrashLogRepository();
      final logger = CrashLogger(
        repository: repo,
        clock: () => DateTime(2026, 11, 1, 9, 31),
      );

      logger.record(StateError('boom'), StackTrace.current, kind: 'zone');
      await Future<void>.delayed(Duration.zero);

      final entries = await repo.loadAll();
      expect(entries.length, 1);
      expect(entries.single.kind, 'zone');
      expect(entries.single.message, contains('boom'));
      expect(entries.single.timestamp, DateTime(2026, 11, 1, 9, 31));
    });

    test('repository が失敗しても record は静かに戻る', () async {
      final logger = CrashLogger(repository: _ThrowingRepository());
      expect(() => logger.record(Exception('x'), null), returnsNormally);
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('summarize', () {
    test('0件は null', () {
      expect(summarize(const []), isNull);
    });

    test('「前回の異常終了 2件（最終 HH:mm）」', () {
      final now = DateTime(2026, 11, 1, 12, 0);
      final entries = [
        _at(DateTime(2026, 11, 1, 9, 30), 'a'),
        _at(DateTime(2026, 11, 1, 9, 31), 'b'),
      ];
      expect(summarize(entries, now: now), '前回の異常終了 2件（最終 09:31）');
    });

    test('並び順に依存せず最終時刻を採る', () {
      final now = DateTime(2026, 11, 1, 12, 0);
      final entries = [
        _at(DateTime(2026, 11, 1, 9, 31), 'b'),
        _at(DateTime(2026, 11, 1, 9, 5), 'a'),
      ];
      expect(
        summarize(entries, now: now),
        '前回の異常終了 2件（最終 09:31）',
      );
    });

    test('別日なら日付付き', () {
      final now = DateTime(2026, 11, 2, 0, 5);
      final entries = [_at(DateTime(2026, 10, 31, 23, 59), 'a')];
      expect(
        summarize(entries, now: now),
        '前回の異常終了 1件（最終 10/31 23:59）',
      );
    });
  });

  group('recent', () {
    test('新しい順に limit 件', () {
      final entries = [
        for (var i = 0; i < 5; i++) _at(DateTime(2026, 11, 1, 9, i), 'e$i'),
      ];
      final picked = recent(entries, limit: 3);
      expect(picked.map((e) => e.message), ['e4', 'e3', 'e2']);
    });
  });
}

class _ThrowingRepository implements CrashLogRepository {
  @override
  Future<void> append(CrashLogEntry entry) async => throw StateError('nope');

  @override
  Future<void> clear() async {}

  @override
  Future<List<CrashLogEntry>> loadAll() async => const [];
}
