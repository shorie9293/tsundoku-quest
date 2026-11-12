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
import 'package:tsundoku_quest/features/reading/data/fallback_reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/data/hive_reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/data/supabase_reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/domain/weekly_reading_buckets.dart';

/// 親探針（合成不変条件） — 週間読書グラフの日付バケット。
///
/// 眷属の試練は「個別の期待値」しか撃たないため、親が以下を独立に撃つ:
///   P1. UI のラベル暦（`now - (6 - i) 日`）と データのバケット暦が 7 日すべて一致する
///   P2. 週初め境界（ローカル 0 時ちょうど = index 0 / その 1 分前 = 圏外で捨てる）
///   P3. ローカル日付で数える（UTC 日付で数えていないことの識別）
///   P4. Fallback（Supabase 主 + Hive 副）の合算が要素ごとに一致し、二重計上しない
///   P5. 実時計（clock 未指定）でも「今日」は index 6
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

  // 固定 clock（ローカル暦）: 2026-11-12 18:00
  final fixedNow = DateTime(2026, 11, 12, 18, 0);

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('weekly_parent_probe');
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

  HiveReadingSessionRepository hiveRepo() =>
      HiveReadingSessionRepository(_MockBoxManager(), clock: () => fixedNow);

  test('P1: UI のラベル暦とデータのバケット暦が 7 日すべて一致する', () async {
    final repo = hiveRepo();
    // UI (weekly_chart_widget.dart) と同じ式でラベル日を作る
    final labelDates = List.generate(
      7,
      (i) => fixedNow.subtract(Duration(days: 6 - i)),
    );

    for (var i = 0; i < 7; i++) {
      final d = labelDates[i];
      // その日のローカル正午 → UTC ISO（1 日 1 セッション、分は i+1）
      final startedAt = DateTime(d.year, d.month, d.day, 12).toUtc().toIso8601String();
      await repo.createSession(_session('p1-$i', startedAt, i + 1));
    }

    final buckets = await repo.getWeeklyReadingMinutes();

    for (var i = 0; i < 7; i++) {
      expect(buckets[i], i + 1,
          reason: 'ラベル index $i（${labelDates[i]}）の棒に当日の分だけが立つ');
    }
    expect(buckets.fold<int>(0, (a, b) => a + b), 28);
  });

  test('P2: 週初め境界 — ローカル0時ちょうどは index 0、その1分前は捨てる', () async {
    final repo = hiveRepo();
    final weekStart = WeeklyReadingBuckets.weekStart(fixedNow);

    // ローカル0時ちょうど（= index 0）
    await repo.createSession(_session(
      'edge-in',
      weekStart.toUtc().toIso8601String(),
      10,
    ));
    // その 1 分前（= 圏外）
    await repo.createSession(_session(
      'edge-out',
      weekStart.subtract(const Duration(minutes: 1)).toUtc().toIso8601String(),
      99,
    ));

    final buckets = await repo.getWeeklyReadingMinutes();

    expect(buckets[0], 10, reason: '週初めちょうどは含む');
    expect(buckets.fold<int>(0, (a, b) => a + b), 10,
        reason: '圏外の 99 分はどのバケットにも入らない');
  });

  test('P3: UTC 日付ではなくローカル日付で数える', () async {
    final repo = hiveRepo();
    // JST 11/12 01:00 = UTC 11/11 16:00（UTC 日付とローカル日付が食い違う瞬間）
    final instant = DateTime(2026, 11, 12, 1, 0).toUtc();
    final localDay = instant.toLocal();
    final utcDay = instant; // isUtc
    final localIndex = DateTime(localDay.year, localDay.month, localDay.day)
        .difference(WeeklyReadingBuckets.weekStart(fixedNow))
        .inDays;
    final utcIndex = DateTime.utc(utcDay.year, utcDay.month, utcDay.day)
        .difference(DateTime.utc(2026, 11, 6))
        .inDays;

    await repo.createSession(
        _session('tz', instant.toIso8601String(), 7));
    final buckets = await repo.getWeeklyReadingMinutes();

    expect(buckets[localIndex], 7, reason: 'ローカル日付のバケットに入る');
    if (localIndex != utcIndex) {
      expect(buckets[utcIndex], 0,
          reason: 'UTC 日付のバケットに入ってはならない（旧実装の誤り）');
    }
  });

  test('P4: Fallback（Supabase 主 + Hive 副）の合算が要素ごとに一致し二重計上しない',
      () async {
    // 主: Supabase（今日 30 分）
    final client = SupabaseClient(
      'http://localhost:54321',
      'test-anon-key',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'started_at': '2026-11-12T09:00:00.000Z',
              'duration_minutes': 30,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final primary =
        SupabaseReadingSessionRepository(client, clock: () => fixedNow);

    // 副: Hive（6 日前 15 分）
    final boxManager = _MockBoxManager();
    final local = HiveReadingSessionRepository(boxManager, clock: () => fixedNow);
    await local.createSession(
        _session('l1', '2026-11-06T00:30:00.000Z', 15));

    final fallback = FallbackReadingSessionRepository(
      primary: primary,
      local: local,
      boxManager: boxManager,
    );

    final buckets = await fallback.getWeeklyReadingMinutes();

    expect(buckets.length, 7);
    expect(buckets[6], 30, reason: '主の今日分');
    expect(buckets[0], 15, reason: '副の最古日分');
    expect(buckets.fold<int>(0, (a, b) => a + b), 45,
        reason: '合算で二重計上しない');
  });

  test('P5: 実時計（clock 未指定）でも「今日」は index 6', () async {
    final repo = HiveReadingSessionRepository(_MockBoxManager());
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await repo.createSession(_session('real', nowIso, 12));

    final buckets = await repo.getWeeklyReadingMinutes();

    expect(buckets[6], 12, reason: '実時計でも今日 = index 6');
    expect(buckets.fold<int>(0, (a, b) => a + b), 12);
  });
}
