import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/reading_session_adapter.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/features/history/data/reading_habit_heatmap_service.dart';
import 'package:tsundoku_quest/features/history/data/reading_habit_provider.dart';
import 'package:tsundoku_quest/features/history/data/weekly_reading_provider.dart';
import 'package:tsundoku_quest/features/reading/data/fallback_reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/data/reading_derived_invalidation.dart';
import 'package:tsundoku_quest/features/reading/domain/weekly_reading_buckets.dart';

/// 親探針（wiring probe）: 「読書セッション書き込み成功 → 派生Provider無効化」の
/// 配線を実物の FallbackReadingSessionRepository + 単一窓口で通しで検証する。
///
/// 可変ストアを両 FutureProvider の override builder が読む構成にし、
/// createSession 後に再読すると新セッションが反映されることを確認する。
class _StoreRepo implements ReadingSessionRepository {
  _StoreRepo(this.store);

  final List<ReadingSession> store;

  @override
  Future<ReadingSession> createSession(ReadingSession session) async {
    store.add(session);
    return session;
  }

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async {
    final session = ReadingSession(
      id: 'remote-${store.length + 1}',
      userBookId: userBookId,
      startedAt: DateTime.now().toUtc().toIso8601String(),
      startPage: startPage,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    store.add(session);
    return session;
  }

  @override
  Future<ReadingSession> endSession(
      String sessionId, int endPage, int durationMinutes) async {
    return ReadingSession(
      id: sessionId,
      userBookId: 'ub-1',
      startedAt: DateTime.now().toUtc().toIso8601String(),
      startPage: 0,
      endPage: endPage,
      durationMinutes: durationMinutes,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> updateSession(ReadingSession session) async {}

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<List<ReadingSession>> getByUserBook(String userBookId) async => store;

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async =>
      store.take(limit).toList();

  @override
  Future<List<String>> getAllReadingDates() async =>
      store.map((s) => s.startedAt.substring(0, 10)).toSet().toList();

  @override
  Future<int> getTotalReadingMinutes(String userBookId) async => 0;

  @override
  Future<int> getTotalReadingMinutesAll() async =>
      store.fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));

  @override
  Future<int> getTotalPagesReadAll() async => 0;

  @override
  Future<List<int>> getWeeklyReadingMinutes() async {
    final buckets = WeeklyReadingBuckets.build(
      store.map((s) => (
            startedAt: s.startedAt,
            durationMinutes: s.durationMinutes,
          )),
      now: DateTime.now(),
    );
    return buckets;
  }

  @override
  Future<int> getCurrentStreak() async => 0;

  @override
  Future<int> getLongestStreak() async => 0;
}

class _HiveBoxManager implements BoxManagerInterface {
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

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('derived_wiring_probe');
    Hive.init(dir.path);
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

  test('createSession 成功で ヒートマップ/週間グラフ の両方が更新される', () async {
    final store = <ReadingSession>[];
    final repo = _StoreRepo(store);
    late final ProviderContainer container;

    container = ProviderContainer(
      overrides: [
        // 可変ストアを読む override（実配線では repository 経由で読まれる）
        readingHabitSessionsProvider.overrideWith((ref) async {
          return List<ReadingSession>.of(store);
        }),
        weeklyReadingMinutesProvider.overrideWith((ref) async {
          return repo.getWeeklyReadingMinutes();
        }),
      ],
    );
    addTearDown(container.dispose);

    // 本番と同じ配線: 書き込み成功 → 単一窓口
    final fallback = FallbackReadingSessionRepository(
      primary: repo,
      local: repo,
      boxManager: _HiveBoxManager(),
      onSuccessfulWrite: () =>
          container.read(readingDerivedInvalidatorProvider)(),
    );

    // 1) キャッシュを温める
    final beforeHabit =
        await container.read(readingHabitSessionsProvider.future);
    final beforeWeekly =
        await container.read(weeklyReadingMinutesProvider.future);
    expect(beforeHabit, isEmpty);
    expect(ReadingHabitHeatmapService.build(sessions: beforeHabit).totalMinutes,
        0);
    expect(beforeWeekly[6], 0, reason: 'index 6 = 今日（ローカル暦）');

    // 2) 書き込み（今日の30分セッション）
    final created = await fallback.createSession(
      ReadingSession(
        id: 'session-1',
        userBookId: 'ub-1',
        startedAt: DateTime.now().toUtc().toIso8601String(),
        endedAt: DateTime.now().toUtc().toIso8601String(),
        startPage: 0,
        endPage: 20,
        durationMinutes: 30,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    expect(created.id, 'session-1');

    // 3) 再読 → 新しいセッションが反映される（invalidate が効いている）
    final afterHabit =
        await container.read(readingHabitSessionsProvider.future);
    expect(afterHabit, hasLength(1));
    expect(afterHabit.first.id, 'session-1');
    expect(
      ReadingHabitHeatmapService.build(sessions: afterHabit).totalMinutes,
      30,
      reason: 'ヒートマップの合計分が 0 → 30 に増えるべき',
    );

    final afterWeekly =
        await container.read(weeklyReadingMinutesProvider.future);
    expect(afterWeekly[6], 30, reason: '週間グラフの index 6（今日）が 0 → 30 に増えるべき');
  });

  test('書き込み失敗時は派生Providerを落とさない（キャッシュ据え置き）', () async {
    final store = <ReadingSession>[];
    final failing = _FailingRepo();
    late final ProviderContainer container;

    container = ProviderContainer(
      overrides: [
        readingHabitSessionsProvider.overrideWith((ref) async {
          return List<ReadingSession>.of(store);
        }),
        weeklyReadingMinutesProvider.overrideWith((ref) async {
          return List<int>.filled(7, 0);
        }),
      ],
    );
    addTearDown(container.dispose);

    final fallback = FallbackReadingSessionRepository(
      primary: failing,
      local: failing,
      boxManager: _HiveBoxManager(),
      onSuccessfulWrite: () =>
          container.read(readingDerivedInvalidatorProvider)(),
    );

    final before = await container.read(readingHabitSessionsProvider.future);
    expect(before, isEmpty);

    await expectLater(
      fallback.createSession(
        ReadingSession(
          id: 'session-x',
          userBookId: 'ub-1',
          startedAt: DateTime.now().toUtc().toIso8601String(),
          startPage: 0,
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      ),
      throwsException,
    );

    final after = await container.read(readingHabitSessionsProvider.future);
    expect(identical(before, after), isTrue,
        reason: '失敗時に invalidate しないので同一キャッシュが返る');
  });
}

class _FailingRepo implements ReadingSessionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw Exception('primary down');
}
