import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/reading_session_adapter.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/data/fallback_reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/data/hive_reading_session_repository.dart';

/// 同期の配線を実 Hive で撃つ試練。
///
/// 固定する不変条件（受入基準）:
/// - 1回目の同期でローカル行（印＋元キー）が消え、二重計上が解消する
/// - 2回目の同期でリモートに同一 PK があっても「反映済み」と解釈して
///   ローカル行を掃除する（＝再試行が永久に失敗しない）
/// - 通算読書分は 60 のまま（120 に増えない）
/// - 反映できていない行は消さない（データ消失防止）
class _FakePostgrestException implements Exception {
  _FakePostgrestException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => 'PostgrestException(message: $message, code: $code)';
}

/// リモート（Supabase）を模す偽プライマリ。同一 id の再 INSERT は
/// 実 DB と同じく重複キー違反（23505）で失敗する。
class _FakeSupabaseRepo implements ReadingSessionRepository {
  final Map<String, ReadingSession> rows = {};
  final List<ReadingSession> createAttempts = [];
  Object? failWith;

  @override
  Future<ReadingSession> createSession(ReadingSession session) async {
    createAttempts.add(session);
    final error = failWith;
    if (error != null) throw error;
    if (rows.containsKey(session.id)) {
      throw _FakePostgrestException(
        code: '23505',
        message: 'duplicate key value violates unique constraint '
            '"reading_sessions_pkey"',
      );
    }
    rows[session.id] = session;
    return session;
  }

  @override
  Future<int> getTotalReadingMinutesAll() async =>
      rows.values.fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));

  @override
  Future<int> getTotalPagesReadAll() async =>
      rows.values.fold<int>(0, (sum, s) => sum + (s.endPage! - s.startPage));

  @override
  Future<List<String>> getAllReadingDates() async =>
      rows.values.map((s) => s.startedAt.substring(0, 10)).toSet().toList();

  @override
  Future<List<int>> getWeeklyReadingMinutes() async => List.filled(7, 0);

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async =>
      throw UnimplementedError();

  @override
  Future<ReadingSession> endSession(
          String sessionId, int endPage, int durationMinutes) async =>
      throw UnimplementedError();

  @override
  Future<List<ReadingSession>> getByUserBook(String userBookId) async =>
      rows.values.where((s) => s.userBookId == userBookId).toList();

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async =>
      rows.values.take(limit).toList();

  @override
  Future<int> getTotalReadingMinutes(String userBookId) async => rows.values
      .where((s) => s.userBookId == userBookId)
      .fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));

  @override
  Future<int> getCurrentStreak() async => 0;

  @override
  Future<int> getLongestStreak() async => 0;

  @override
  Future<void> updateSession(ReadingSession session) async {}

  @override
  Future<void> deleteSession(String sessionId) async {}
}

class _TestBoxManager implements BoxManagerInterface {
  @override
  Future<Box<T>> getBox<T>(String name) async => Hive.box<T>(name);

  @override
  Future<void> openAllBoxes() async {}

  @override
  Future<void> closeBox(String name) async {}

  @override
  Future<void> closeAllBoxes() async {}

  @override
  Future<void> clearBox(String name) async {}
}

ReadingSession _session(
  String id, {
  int minutes = 60,
  String? endedAt = '2026-11-10T01:00:00.000Z',
}) =>
    ReadingSession(
      id: id,
      userBookId: 'ub-sync',
      startedAt: '2026-11-10T00:00:00.000Z',
      endedAt: endedAt,
      startPage: 0,
      endPage: 100,
      durationMinutes: minutes,
      createdAt: '2026-11-10T00:00:00.000Z',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BoxManagerInterface boxManager;
  late HiveReadingSessionRepository localRepo;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('hive_sync_wiring');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ReadingSessionAdapter());
    }
  });

  setUp(() async {
    await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
    boxManager = _TestBoxManager();
    localRepo = HiveReadingSessionRepository(boxManager);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  Future<void> seedOfflineSession({int minutes = 60}) async {
    final box = await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
    // オフライン完結: 元キー行に完了データ、印行は local: 付き
    await box.put('raw-1', _session('raw-1', minutes: minutes));
    await box.put('local:raw-1', _session('local:raw-1', minutes: 0));
    await box.flush();
  }

  FallbackReadingSessionRepository build(_FakeSupabaseRepo primary) =>
      FallbackReadingSessionRepository(
        primary: primary,
        local: localRepo,
        boxManager: boxManager,
      );

  group('syncLocalSessionsToRemote 冪等化', () {
    test('1回目の同期でローカル行が消え、通算が二重にならない', () async {
      await seedOfflineSession();
      final primary = _FakeSupabaseRepo();
      final repo = build(primary);

      await repo.syncLocalSessionsToRemote();

      final box = await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
      expect(box.isEmpty, isTrue, reason: '印行と元キー行の両方が消える（残ると加算で二重）');
      expect(primary.rows.keys, ['raw-1']);
      expect(await repo.getTotalReadingMinutesAll(), 60);
      expect(await repo.getTotalPagesReadAll(), 100);
    });

    test('2回目の同期: リモートに同一 PK があれば反映済みと解釈してローカル行を消す', () async {
      await seedOfflineSession();
      final primary = _FakeSupabaseRepo();
      // 前回の部分成功: リモートには入っているがローカル行が残っている
      primary.rows['raw-1'] = _session('raw-1');
      final repo = build(primary);

      await repo.syncLocalSessionsToRemote();

      final box = await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
      expect(box.isEmpty, isTrue, reason: '重複キーは「反映済み」であり再試行失敗ではない');
      expect(primary.rows, hasLength(1), reason: 'リモートの行は増えない');
      expect(await repo.getTotalReadingMinutesAll(), 60,
          reason: '通算は60分のまま（120分になってはならない）');
    });

    test('同じ状況で2回同期しても通算60分のまま（冪等）', () async {
      await seedOfflineSession();
      final primary = _FakeSupabaseRepo()..rows['raw-1'] = _session('raw-1');
      final repo = build(primary);

      await repo.syncLocalSessionsToRemote();
      await repo.syncLocalSessionsToRemote();

      expect(await repo.getTotalReadingMinutesAll(), 60);
      expect(primary.rows, hasLength(1));
      expect(primary.createAttempts, hasLength(1),
          reason: '1回目でローカル行が消えるため2回目は push しない');
    });

    test('無関係なエラーではローカル行を消さない（データ消失防止）', () async {
      await seedOfflineSession();
      final primary = _FakeSupabaseRepo()..failWith = Exception('network down');
      final repo = build(primary);

      await repo.syncLocalSessionsToRemote();

      final box = await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
      expect(box.containsKey('raw-1'), isTrue,
          reason: '反映できていない完了データは残す（次回再試行）');
      expect(box.containsKey('local:raw-1'), isTrue);
      expect(await repo.getTotalReadingMinutesAll(), 60,
          reason: 'リモート未反映なのでローカルの60分のみ');
    });

    test('未完了セッションは push も削除もしない', () async {
      final box = await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
      await box.put('raw-2', _session('raw-2', minutes: 0, endedAt: null));
      await box.put('local:raw-2', _session('local:raw-2', minutes: 0));
      final primary = _FakeSupabaseRepo();
      final repo = build(primary);

      await repo.syncLocalSessionsToRemote();

      expect(primary.createAttempts, isEmpty, reason: '読書中の行は同期しない');
      expect(box.containsKey('raw-2'), isTrue);
      expect(box.containsKey('local:raw-2'), isTrue, reason: '完了後に同期できるよう印は残す');
    });

    test('元キー行が無い印だけの行は掃除される（孤児の残留防止）', () async {
      final box = await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
      await box.put('local:gone', _session('local:gone', minutes: 0));
      final primary = _FakeSupabaseRepo();
      final repo = build(primary);

      await repo.syncLocalSessionsToRemote();

      expect(box.containsKey('local:gone'), isFalse);
      expect(primary.createAttempts, isEmpty);
    });

    test('複数件をまとめて同期し、すべて掃除される（通算は合計）', () async {
      final box = await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
      await box.put('raw-a', _session('raw-a'));
      await box.put('local:raw-a', _session('local:raw-a', minutes: 0));
      await box.put('raw-b', _session('raw-b', minutes: 30));
      await box.put('local:raw-b', _session('local:raw-b', minutes: 0));
      final primary = _FakeSupabaseRepo();
      final repo = build(primary);

      await repo.syncLocalSessionsToRemote();

      expect(primary.rows.keys.toSet(), {'raw-a', 'raw-b'});
      expect(box.isEmpty, isTrue);
      expect(await repo.getTotalReadingMinutesAll(), 90);
    });
  });
}
