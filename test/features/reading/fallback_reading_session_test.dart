import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/data/fallback_reading_session_repository.dart';

/// FallbackReadingSessionRepository
///
/// Supabase の startSession が失敗した場合でも Hive（ローカル）に
/// セッションが書かれ、endSession も Hive 側で完結することを検証する。
import 'dart:io';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/reading_session_adapter.dart';
class _FailingRepo implements ReadingSessionRepository {
  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async =>
      throw Exception('Supabase down');

  @override
  Future<ReadingSession> createSession(ReadingSession session) async =>
      throw Exception('Supabase down');

  @override
  Future<ReadingSession> endSession(
          String sessionId, int endPage, int durationMinutes) async =>
      throw Exception('Supabase down');

  @override
  Future<List<ReadingSession>> getByUserBook(String userBookId) async => [];

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async => [];

  @override
  Future<List<String>> getAllReadingDates() async => [];

  @override
  Future<int> getTotalReadingMinutes(String userBookId) async => 0;

  @override
  Future<int> getTotalReadingMinutesAll() async => 0;

  @override
  Future<int> getTotalPagesReadAll() async => 0;

  @override
  Future<List<int>> getWeeklyReadingMinutes() async => List.filled(7, 0);

  @override
  Future<int> getCurrentStreak() async => 0;

  @override
  Future<int> getLongestStreak() async => 0;
}

/// 正常なプライマリリポジトリ
class _WorkingRepo implements ReadingSessionRepository {
  ReadingSession? lastStarted;
  int lastEndMinutes = 0;
  String? lastEndedSessionId;
  bool endCalled = false;
  final List<ReadingSession> created = [];

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async {
    lastStarted = ReadingSession(
      id: 'remote-1',
      userBookId: userBookId,
      startedAt: DateTime.now().toUtc().toIso8601String(),
      startPage: startPage,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    return lastStarted!;
  }

  @override
  Future<ReadingSession> createSession(ReadingSession session) async {
    created.add(session);
    return session;
  }

  @override
  Future<ReadingSession> endSession(
      String sessionId, int endPage, int durationMinutes) async {
    endCalled = true;
    lastEndedSessionId = sessionId;
    lastEndMinutes = durationMinutes;
    return ReadingSession(
      id: sessionId,
      userBookId: 'ub',
      startedAt: DateTime.now().toUtc().toIso8601String(),
      startPage: 0,
      endPage: endPage,
      durationMinutes: durationMinutes,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Future<List<ReadingSession>> getByUserBook(String userBookId) async => [];
  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async => [];
  @override
  Future<List<String>> getAllReadingDates() async => [];
  @override
  Future<int> getTotalReadingMinutes(String userBookId) async => 0;
  @override
  Future<int> getTotalReadingMinutesAll() async => 0;
  @override
  Future<int> getTotalPagesReadAll() async => 0;
  @override
  Future<List<int>> getWeeklyReadingMinutes() async => List.filled(7, 0);
  @override
  Future<int> getCurrentStreak() async => 0;
  @override
  Future<int> getLongestStreak() async => 0;
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('hive_fallback_test');
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

  group('FallbackReadingSessionRepository', () {
    test('startSession 失敗時、ローカルでセッションが作られ local: 印付きで返る',
        () async {
      final primary = _FailingRepo();
      final repo = FallbackReadingSessionRepository(
        primary: primary,
        local: _HiveBackedLocalRepo(),
        boxManager: _MockBoxManager(),
      );

      final session = await repo.startSession('ub1', 0);

      expect(session.id.startsWith('local:'), isTrue,
          reason: 'ローカル発セッションには local: プレフィックスが付くべき');
    });

    test('startSession 成功時、プライマリの結果がそのまま返る', () async {
      final primary = _WorkingRepo();
      final repo = FallbackReadingSessionRepository(
        primary: primary,
        local: _HiveBackedLocalRepo(),
        boxManager: _MockBoxManager(),
      );
      final session = await repo.startSession('ub1', 0);

      expect(session.id, 'remote-1');
      expect(session.id.startsWith('local:'), isFalse);
    });

    test('local: セッションの endSession はローカルで完結する', () async {
      final primaryFailing = _FailingRepo();
      final repo = FallbackReadingSessionRepository(
        primary: primaryFailing,
        local: _HiveBackedLocalRepo(),
        boxManager: _MockBoxManager(),
      );

      final session = await repo.startSession('ub1', 0);
      final ended = await repo.endSession(session.id, 42, 30);

      expect(ended.durationMinutes, 30);
      expect(ended.endPage, 42);
    });

    test('リモートセッションの endSession はプライマリに委譲される', () async {
      final primary = _WorkingRepo();
      final repo = FallbackReadingSessionRepository(
        primary: primary,
        local: _HiveBackedLocalRepo(),
        boxManager: _MockBoxManager(),
      );
      await repo.startSession('ub1', 0);
      await repo.endSession('remote-1', 42, 15);

      expect(primary.endCalled, isTrue);
      expect(primary.lastEndMinutes, 15);
    });

    test('getAllReadingDates はプライマリとローカルをマージする', () async {
      final repo = FallbackReadingSessionRepository(
        primary: _DatesRepo(['2026-09-11']),
        local: _HiveBackedLocalRepo(),
        boxManager: _MockBoxManager(),
      );

      // ローカルに1セッション追加
      await repo.startSession('ub1', 0);
      await repo.endSession(
          (await repo.startSession('ub1', 0)).id, 10, 5);

      final dates = await repo.getAllReadingDates();
      expect(dates.contains('2026-09-11'), isTrue,
          reason: 'プライマリの読書日がマージされるべき');
    });

    test('syncLocalSessionsToRemote は完了データを元のタイムスタンプのまま同期し印を消す',
        () async {
      // 1. オフライン想定でローカル退避セッションを作成・完了
      final failingPrimary = _FailingRepo();
      final offlineRepo = FallbackReadingSessionRepository(
        primary: failingPrimary,
        local: _HiveBackedLocalRepo(),
        boxManager: _MockBoxManager(),
      );
      final started = await offlineRepo.startSession('ub-sync', 0);
      final ended = await offlineRepo.endSession(started.id, 120, 45);
      expect(ended.durationMinutes, 45);

      // 2. オンライン復帰: 正常なプライマリで同期
      final primary = _WorkingRepo();
      final onlineRepo = FallbackReadingSessionRepository(
        primary: primary,
        local: _HiveBackedLocalRepo(),
        boxManager: _MockBoxManager(),
      );
      await onlineRepo.syncLocalSessionsToRemote();

      // 3. 検証: createSession で完了データ（45分・元のstartedAt）が同期された
      expect(primary.created, hasLength(1),
          reason: '完了セッションが1件同期されるべき');
      expect(primary.created.first.durationMinutes, 45,
          reason: 'duration 0 ではなく実際の読書時間が同期されるべき');
      expect(primary.created.first.endedAt, isNotNull);
      expect(primary.created.first.startedAt, ended.startedAt,
          reason: '元の読書開始時刻が保持されるべき（日付シフト防止）');

      // 4. local: 印付き重複行は削除済み（元キー行も削除され二重集計なし）
      final box =
          await Hive.openBox<ReadingSession>(BoxNames.readingSessions);
      final markedLeft = box.values
          .where((s) => s.id.startsWith('local:'))
          .toList();
      expect(markedLeft, isEmpty, reason: '同期済の local: 印行は削除されるべき');
      final rawLeft = box.values
          .where((s) => s.userBookId == 'ub-sync')
          .toList();
      expect(rawLeft, isEmpty,
          reason: '同期済の元キー行も削除されるべき（二重集計防止）');
    });

    test('syncLocalSessionsToRemote は再入時に二重同期しない', () async {
      final failingPrimary = _FailingRepo();
      final offlineRepo = FallbackReadingSessionRepository(
        primary: failingPrimary,
        local: _HiveBackedLocalRepo(),
        boxManager: _MockBoxManager(),
      );
      final started = await offlineRepo.startSession('ub-reentry', 0);
      await offlineRepo.endSession(started.id, 50, 10);

      final primary = _WorkingRepo();
      final repo = FallbackReadingSessionRepository(
        primary: primary,
        local: _HiveBackedLocalRepo(),
        boxManager: _MockBoxManager(),
      );
      // 同時に2回トリガー（アプリ復帰 + 接続イベント想定）
      await Future.wait([
        repo.syncLocalSessionsToRemote(),
        repo.syncLocalSessionsToRemote(),
      ]);

      expect(primary.created, hasLength(1),
          reason: '再入ガードにより1セッションは1回のみ同期されるべき');
    });
  });
}

/// 固定日付を返すプライマリ（マージテスト用）
class _DatesRepo implements ReadingSessionRepository {
  final List<String> dates;
  _DatesRepo(this.dates);

  @override
  Future<List<String>> getAllReadingDates() async => dates;

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async =>
      throw UnimplementedError();

  @override
  Future<ReadingSession> endSession(
          String sessionId, int endPage, int durationMinutes) async =>
      throw UnimplementedError();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Hive を直接使うローカル実装（テスト用簡易版）
class _HiveBackedLocalRepo implements ReadingSessionRepository {
  static int _counter = 0;

  Future<Box<ReadingSession>> get _box async =>
      Hive.openBox<ReadingSession>(BoxNames.readingSessions);

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async {
    final box = await _box;
    final now = DateTime.now().toUtc().toIso8601String();
    final session = ReadingSession(
      id: 'local-test-${_counter++}',
      userBookId: userBookId,
      startedAt: now,
      startPage: startPage,
      createdAt: now,
    );
    await box.put(session.id, session);
    return session;
  }

  @override
  Future<ReadingSession> createSession(ReadingSession session) async {
    final box = await _box;
    await box.put(session.id, session);
    return session;
  }

  @override
  Future<ReadingSession> endSession(
      String sessionId, int endPage, int durationMinutes) async {
    final box = await _box;
    final existing = box.get(sessionId);
    if (existing == null) {
      throw StateError('Session not found: $sessionId');
    }
    final updated = ReadingSession(
      id: existing.id,
      userBookId: existing.userBookId,
      startedAt: existing.startedAt,
      endedAt: DateTime.now().toUtc().toIso8601String(),
      startPage: existing.startPage,
      endPage: endPage,
      durationMinutes: durationMinutes,
      createdAt: existing.createdAt,
    );
    await box.put(sessionId, updated);
    return updated;
  }

  @override
  Future<List<ReadingSession>> getByUserBook(String userBookId) async =>
      (await _box).values.where((s) => s.userBookId == userBookId).toList();

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async =>
      (await _box).values.take(limit).toList();

  @override
  Future<List<String>> getAllReadingDates() async {
    final box = await _box;
    final dateSet = <String>{};
    for (final s in box.values) {
      final d = s.startedAt.length >= 10
          ? s.startedAt.substring(0, 10)
          : s.startedAt;
      dateSet.add(d);
    }
    final result = dateSet.toList()..sort((a, b) => b.compareTo(a));
    return result;
  }

  @override
  Future<int> getTotalReadingMinutes(String userBookId) async => 0;

  @override
  Future<int> getTotalReadingMinutesAll() async {
    final box = await _box;
    return box.values.fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));
  }

  @override
  Future<int> getTotalPagesReadAll() async => 0;

  @override
  Future<List<int>> getWeeklyReadingMinutes() async => List.filled(7, 0);

  @override
  Future<int> getCurrentStreak() async => 0;

  @override
  Future<int> getLongestStreak() async => 0;
}
