import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/reading_session_adapter.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/reading/data/hive_reading_session_repository.dart';

/// 日付キー配線試練（Hive 実装）。
///
/// 保存は UTC ISO・日付キーはローカル暦。
/// UTC 20:00Z のセッションが「ローカル日付」で返ることを固定する。
/// TZ=Asia/Tokyo / TZ=UTC の双方で緑になること。

/// インメモリ BoxManager モック（実 Hive を起動しない）
class _MockBoxManager implements BoxManagerInterface {
  final Map<String, Box> _boxes = {};

  @override
  Future<Box<T>> getBox<T>(String name) async {
    return _boxes.putIfAbsent(name, () => Hive.box<T>(name)) as Box<T>;
  }

  @override
  Future<void> openAllBoxes() async {}

  @override
  Future<void> closeBox(String name) async {}

  @override
  Future<void> closeAllBoxes() async {}

  @override
  Future<void> clearBox(String name) async {}
}

ReadingSession _session(String id, String startedAt) => ReadingSession(
      id: id,
      userBookId: 'ub1',
      startedAt: startedAt,
      startPage: 0,
      durationMinutes: 10,
      createdAt: startedAt,
    );

/// ローカル暦の期待値（特定TZを決め打ちしない）
String _expectedLocal(String raw) {
  final local = DateTime.parse(raw).toLocal();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('date_key_wiring');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ReadingSessionAdapter());
    }
  });

  setUp(() async {
    await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  group('HiveReadingSessionRepository.getAllReadingDates', () {
    test('UTC 20:00Z のセッションはローカル日付で返る', () async {
      const raw = '2026-11-12T20:00:00.000Z';
      final repo = HiveReadingSessionRepository(_MockBoxManager());
      await repo.createSession(_session('s1', raw));

      final dates = await repo.getAllReadingDates();

      expect(dates, [_expectedLocal(raw)]);
      // ローカル暦が UTC 暦とずれる TZ では、旧実装の値と食い違うはず。
      if (_expectedLocal(raw) != raw.substring(0, 10)) {
        expect(dates, isNot([raw.substring(0, 10)]),
            reason: 'UTC の先頭10文字切り出しへ戻ってはならない');
      }
      if (DateTime.parse(raw).toLocal().timeZoneOffset ==
          const Duration(hours: 9)) {
        expect(dates.first, '2026-11-13', reason: 'JST では翌日');
      }
    });

    test('重複排除・降順・壊れ値除外', () async {
      final repo = HiveReadingSessionRepository(_MockBoxManager());
      await repo.createSession(_session('a', '2026-11-10T00:00:00.000Z'));
      await repo.createSession(_session('b', '2026-11-12T00:00:00.000Z'));
      await repo.createSession(_session('c', '2026-11-10T12:00:00.000Z'));
      await repo.createSession(_session('d', 'not-a-date'));

      final dates = await repo.getAllReadingDates();
      final expected = <String>{
        _expectedLocal('2026-11-10T00:00:00.000Z'),
        _expectedLocal('2026-11-12T00:00:00.000Z'),
        _expectedLocal('2026-11-10T12:00:00.000Z'),
      }.toList()
        ..sort((a, b) => b.compareTo(a));

      expect(dates, expected);
      expect(dates.where((d) => d == 'not-a-date'), isEmpty);
    });

    test('空 box では空リスト', () async {
      final repo = HiveReadingSessionRepository(_MockBoxManager());
      expect(await repo.getAllReadingDates(), isEmpty);
    });
  });
}