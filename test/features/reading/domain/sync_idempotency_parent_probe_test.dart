import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/reading_session_adapter.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/data/fallback_reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/data/hive_reading_session_repository.dart';

/// 親探針: オフライン退避 → オンライン復帰 の合成を **本番経路**（Fallback の
/// startSession/endSession/syncLocalSessionsToRemote）で撃ち、読書時間が
/// 二重計上しないこと・同期が冪等であることを独立に検証する。
///
/// 子の試練は executor を手組みするため「本番が正しく結線されているか」を
/// 検証できない。ここでは本番の Fallback だけを使う。
class _FakePostgrestException implements Exception {
  _FakePostgrestException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => 'PostgrestException(message: $message, code: $code)';
}

/// リモート（Supabase）を模す。同一 id の再 INSERT は実 DB 同様 23505。
/// [closeBoxAfterInsert] を与えると「INSERT 成功直後にプロセスが落ちて
/// ローカル削除に到達しなかった」状況を再現する（部分成功）。
class _FakeRemote implements ReadingSessionRepository {
  _FakeRemote({this.closeBoxAfterInsert});

  final Map<String, ReadingSession> rows = {};
  int createCalls = 0;
  Object? failWith;
  Future<void> Function()? closeBoxAfterInsert;

  @override
  Future<ReadingSession> createSession(ReadingSession session) async {
    createCalls++;
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
    final hook = closeBoxAfterInsert;
    if (hook != null) await hook();
    return session;
  }

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async =>
      throw Exception('Supabase down');

  @override
  Future<int> getTotalReadingMinutesAll() async =>
      rows.values.fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));

  @override
  Future<int> getTotalPagesReadAll() async => rows.values.fold<int>(
      0, (sum, s) => sum + ((s.endPage ?? 0) - s.startPage));

  @override
  Future<List<String>> getAllReadingDates() async => const [];

  @override
  Future<List<int>> getWeeklyReadingMinutes() async => List.filled(7, 0);

  @override
  Future<int> getTotalReadingMinutes(String userBookId) async =>
      rows.values.fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));

  @override
  Future<List<ReadingSession>> getByUserBook(String userBookId) async =>
      rows.values.where((s) => s.userBookId == userBookId).toList();

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async =>
      rows.values.take(limit).toList();

  @override
  Future<int> getCurrentStreak() async => 0;

  @override
  Future<int> getLongestStreak() async => 0;

  @override
  Future<ReadingSession> endSession(
          String sessionId, int endPage, int durationMinutes) async =>
      throw Exception('Supabase down');

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BoxManagerInterface boxManager;
  late HiveReadingSessionRepository localRepo;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('hive_sync_parent');
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

  FallbackReadingSessionRepository build(_FakeRemote primary) =>
      FallbackReadingSessionRepository(
        primary: primary,
        local: localRepo,
        boxManager: boxManager,
      );

  /// オフラインで読書1回（start→end）を完結させ、box に
  /// 「local: 印行」と「元キー行」を作る（本番の startSession/endSession 経由）。
  Future<void> readOffline(FallbackReadingSessionRepository repo,
      {int minutes = 60}) async {
    final started = await repo.startSession('ub-parent', 0);
    expect(started.id.startsWith('local:'), isTrue,
        reason: 'プライマリ失敗時はローカル退避される');
    await repo.endSession(started.id, 100, minutes);
  }

  group('親探針: 退避→復帰の合成', () {
    test('P1 本番経路の合成: 復帰同期後の通算が二重にならない', () async {
      final remote = _FakeRemote();
      final repo = build(remote);

      await readOffline(repo);
      // 復帰前はローカルのみ＝60分
      expect(await repo.getTotalReadingMinutesAll(), 60);

      await repo.syncLocalSessionsToRemote();

      expect(remote.rows, hasLength(1), reason: 'リモートに1行だけ入る');
      expect(await repo.getTotalReadingMinutesAll(), 60,
          reason: 'primary+local の加算で 120 になってはならない');
      expect(await repo.getTotalPagesReadAll(), 100);

      final box = await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
      expect(box.isEmpty, isTrue, reason: '同期後はローカル行が残らない');
    });

    test('P2 冪等: 同期を3回繰り返しても通算・リモート行数が不変', () async {
      final remote = _FakeRemote();
      final repo = build(remote);
      await readOffline(repo);

      for (var i = 0; i < 3; i++) {
        await repo.syncLocalSessionsToRemote();
      }

      expect(remote.rows, hasLength(1));
      expect(await repo.getTotalReadingMinutesAll(), 60);
      expect(remote.createCalls, 1,
          reason: '2回目以降はローカル行が無いので push しない');
    });

    test('P3 部分成功の自己修復: INSERT成功→ローカル削除失敗でも次回同期で単一に戻る',
        () async {
      // 1回目の INSERT 直後に box を閉じ、削除に到達できない状況を作る
      final remote = _FakeRemote(closeBoxAfterInsert: () async {
        final box =
            await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
        await box.close();
      });
      final repo = build(remote);

      await readOffline(repo);
      await repo.syncLocalSessionsToRemote(); // ここで削除が失敗する

      expect(remote.rows, hasLength(1), reason: 'INSERT は成功している');
      var box = await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
      expect(box.isEmpty, isFalse, reason: '削除は失敗しローカル行が残る');

      // 次回同期（重複キー → 反映済み → 掃除）
      remote.closeBoxAfterInsert = null;
      await repo.syncLocalSessionsToRemote();

      box = await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
      expect(box.isEmpty, isTrue,
          reason: '重複キーを「反映済み」と解釈して掃除する（永久二重の根治）');
      expect(await repo.getTotalReadingMinutesAll(), 60,
          reason: '自己修復後は二重が解消される');
      expect(remote.rows, hasLength(1));
    });

    test('P4 無関係な失敗ではローカル行を消さない（データ消失防止）', () async {
      final remote = _FakeRemote()..failWith = Exception('network timeout');
      final repo = build(remote);
      await readOffline(repo);

      await repo.syncLocalSessionsToRemote();

      expect(remote.rows, isEmpty);
      final box = await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
      expect(box.isEmpty, isFalse, reason: '反映できていない行は残して再試行する');
      expect(await repo.getTotalReadingMinutesAll(), 60,
          reason: 'ローカルの読書時間は失われない');
    });

    test('P5 未完了セッションは同期しない（読書中を飛ばす）', () async {
      final remote = _FakeRemote();
      final repo = build(remote);
      await repo.startSession('ub-parent', 0); // endSession しない

      await repo.syncLocalSessionsToRemote();

      expect(remote.rows, isEmpty, reason: 'duration が無い行は push しない');
      final box = await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
      expect(box.isEmpty, isFalse, reason: '読書中の行は温存する');
    });
  });
}
