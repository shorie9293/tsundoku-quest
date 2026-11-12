import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/reading_session_adapter.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/features/reading/data/hive_reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/data/supabase_reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/domain/weekly_reading_buckets.dart';

/// 週間読書グラフの配線試練。
///
/// 1日ズレの再発防止：
///   - index 6 = 今日 / index 0 = 6日前（ローカル暦）
///   - Supabase クエリ下限 = ローカル週初めの UTC ISO
///   - 壊れた startedAt でも throw しない
///
/// TZ=Asia/Tokyo / TZ=UTC の双方で緑になること（時限爆弾を残さない）。

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

ReadingSession _session(String id, String startedAt, int? minutes) =>
    ReadingSession(
      id: id,
      userBookId: 'ub1',
      startedAt: startedAt,
      startPage: 0,
      durationMinutes: minutes,
      createdAt: startedAt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 固定 clock: ローカル 2026-11-12 18:00 → 週初めはローカル 2026-11-06 00:00
  final fixedNow = DateTime(2026, 11, 12, 18, 0);

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('weekly_wiring');
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

  group('HiveReadingSessionRepository.getWeeklyReadingMinutes', () {
    test('今日のセッションは index 6 に入り、index 5 は 0', () async {
      final repo = HiveReadingSessionRepository(
        _MockBoxManager(),
        clock: () => fixedNow,
      );
      // 2026-11-12T09:00Z = JST 18:00 → ローカル 11/12（今日）
      await repo.createSession(_session('s1', '2026-11-12T09:00:00.000Z', 30));

      final buckets = await repo.getWeeklyReadingMinutes();

      expect(buckets[6], 30, reason: 'index 6 は今日');
      expect(buckets[5], 0, reason: 'index 5 は昨日。今日の分が混入してはならない');
    });

    test('6日前のセッションは index 0 に入る（捨てられない）', () async {
      final repo = HiveReadingSessionRepository(
        _MockBoxManager(),
        clock: () => fixedNow,
      );
      // 2026-11-06T00:30Z → ローカル日付 11/06（JST/UTC 双方で 11/06）
      await repo.createSession(_session('s2', '2026-11-06T00:30:00.000Z', 15));

      final buckets = await repo.getWeeklyReadingMinutes();

      expect(buckets[0], 15, reason: '最古の日が index -1 で捨てられてはならない');
    });

    test('合計が投入した durationMinutes の総和と一致する', () async {
      final repo = HiveReadingSessionRepository(
        _MockBoxManager(),
        clock: () => fixedNow,
      );
      await repo.createSession(_session('a', '2026-11-12T09:00:00.000Z', 30));
      await repo.createSession(_session('b', '2026-11-06T00:30:00.000Z', 15));
      await repo.createSession(_session('c', '2026-11-09T03:00:00.000Z', 42));

      final buckets = await repo.getWeeklyReadingMinutes();

      expect(buckets.fold<int>(0, (a, b) => a + b), 30 + 15 + 42);
    });

    test('返り値は常に長さ 7（空 box でも）', () async {
      final empty = HiveReadingSessionRepository(
        _MockBoxManager(),
        clock: () => fixedNow,
      );
      expect((await empty.getWeeklyReadingMinutes()).length,
          WeeklyReadingBuckets.days);

      final repo = HiveReadingSessionRepository(
        _MockBoxManager(),
        clock: () => fixedNow,
      );
      await repo.createSession(_session('a', '2026-11-12T09:00:00.000Z', 30));
      expect((await repo.getWeeklyReadingMinutes()).length, 7);
    });

    test('durationMinutes が null のセッションは加算されない', () async {
      final repo = HiveReadingSessionRepository(
        _MockBoxManager(),
        clock: () => fixedNow,
      );
      await repo.createSession(
          _session('null-minute', '2026-11-12T09:00:00.000Z', null));
      await repo.createSession(_session('ok', '2026-11-12T10:00:00.000Z', 10));

      final buckets = await repo.getWeeklyReadingMinutes();

      expect(buckets[6], 10);
      expect(buckets.fold<int>(0, (a, b) => a + b), 10);
    });

    test('壊れた startedAt があっても throw せず他は正しく集計される', () async {
      final repo = HiveReadingSessionRepository(
        _MockBoxManager(),
        clock: () => fixedNow,
      );
      await repo.createSession(_session('empty', '', 99));
      await repo.createSession(_session('garbage', 'not-a-date', 99));
      await repo.createSession(_session('ok', '2026-11-12T09:00:00.000Z', 30));

      late Future<List<int>> pending;
      expect(
        () => pending = repo.getWeeklyReadingMinutes(),
        returnsNormally,
        reason: '壊れた startedAt で throw してはならない',
      );

      final buckets = await pending;
      expect(buckets[6], 30);
      expect(buckets.fold<int>(0, (a, b) => a + b), 30);
    });

    test('clock 未指定でも従来通り動く（既存呼出の互換）', () async {
      final repo = HiveReadingSessionRepository(_MockBoxManager());
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await repo.createSession(_session('now', nowUtc, 20));

      final buckets = await repo.getWeeklyReadingMinutes();

      expect(buckets.length, 7);
      expect(buckets[6], 20, reason: 'clock 未指定 = DateTime.now。今日は index 6');
    });
  });

  group('WeeklyReadingBuckets.weekStartIso', () {
    test('ローカル週初め 0 時を UTC ISO（Z 付き）で返す', () {
      final iso = WeeklyReadingBuckets.weekStartIso(fixedNow);

      expect(iso, DateTime(2026, 11, 6).toUtc().toIso8601String());
      expect(iso.endsWith('Z'), isTrue);
      // JST 環境なら 2026-11-05T15:00:00.000Z
      if (DateTime(2026, 11, 6).timeZoneOffset == const Duration(hours: 9)) {
        expect(iso, '2026-11-05T15:00:00.000Z');
      }
    });
  });

  group('SupabaseReadingSessionRepository.getWeeklyReadingMinutes', () {
    test('クエリ下限は weekStartIso(now)。集計は純粋モジュールへ委譲', () async {
      final requested = <Uri>[];
      final client = SupabaseClient(
        'http://localhost:54321',
        'test-anon-key',
        httpClient: MockClient((request) async {
          requested.add(request.url);
          return http.Response(
            jsonEncode([
              {
                'started_at': '2026-11-12T09:00:00.000Z',
                'duration_minutes': 30,
              },
              {
                'started_at': '2026-11-06T00:30:00.000Z',
                'duration_minutes': 15,
              },
              // 型ガードで捨てられる行
              {
                'started_at': '2026-11-12T09:00:00.000Z',
                'duration_minutes': '30',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            // postgrest は response.request を参照する
            request: request,
          );
        }),
      );
      final repo = SupabaseReadingSessionRepository(
        client,
        clock: () => fixedNow,
      );

      final buckets = await repo.getWeeklyReadingMinutes();

      expect(requested, hasLength(1));
      expect(
        requested.single.queryParameters['started_at'],
        'gte.${WeeklyReadingBuckets.weekStartIso(fixedNow)}',
      );
      expect(buckets.length, 7);
      expect(buckets[6], 30);
      expect(buckets[0], 15);
      expect(buckets.fold<int>(0, (a, b) => a + b), 45);
    });
  });
}
