import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/adapters/reading_session_adapter.dart';
import 'package:tsundoku_quest/core/infrastructure/hive/box_manager.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/repositories/reading_session_repository.dart';
import 'package:tsundoku_quest/features/history/data/reading_habit_provider.dart';
import 'package:tsundoku_quest/features/history/data/weekly_reading_provider.dart';
import 'package:tsundoku_quest/features/reading/data/fallback_reading_session_repository.dart';
import 'package:tsundoku_quest/features/reading/data/reading_derived_invalidation.dart';

/// 書き込み成功フック（単一窓口）の試練。
///
/// - 窓口: invalidate を呼べば両 FutureProvider が再評価される／呼ばなければ
///   されない（アブレーションの対照）。
/// - Fallback: 書き込み5経路の成功時のみ1回、失敗時0回、読み取り時0回。
ReadingSession _session(String id, {int minutes = 30}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return ReadingSession(
    id: id,
    userBookId: 'ub-1',
    startedAt: now,
    endedAt: now,
    startPage: 0,
    endPage: 10,
    durationMinutes: minutes,
    createdAt: now,
  );
}

class _FakeRepo implements ReadingSessionRepository {
  _FakeRepo({this.throwOnWrite = false});

  final bool throwOnWrite;
  final List<ReadingSession> written = [];
  int readCalls = 0;

  @override
  Future<ReadingSession> createSession(ReadingSession session) async {
    if (throwOnWrite) throw Exception('primary down');
    written.add(session);
    return session;
  }

  @override
  Future<ReadingSession> startSession(String userBookId, int startPage) async {
    if (throwOnWrite) throw Exception('primary down');
    return _session('remote-start');
  }

  @override
  Future<ReadingSession> endSession(
      String sessionId, int endPage, int durationMinutes) async {
    if (throwOnWrite) throw Exception('primary down');
    return _session(sessionId, minutes: durationMinutes);
  }

  @override
  Future<void> updateSession(ReadingSession session) async {
    if (throwOnWrite) throw Exception('primary down');
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    if (throwOnWrite) throw Exception('primary down');
  }

  @override
  Future<List<ReadingSession>> getByUserBook(String userBookId) async {
    readCalls++;
    return const [];
  }

  @override
  Future<List<ReadingSession>> getRecentSessions({int limit = 10}) async {
    readCalls++;
    return const [];
  }

  @override
  Future<List<String>> getAllReadingDates() async {
    readCalls++;
    return const [];
  }

  @override
  Future<int> getTotalReadingMinutes(String userBookId) async {
    readCalls++;
    return 0;
  }

  @override
  Future<int> getTotalReadingMinutesAll() async {
    readCalls++;
    return 0;
  }

  @override
  Future<int> getTotalPagesReadAll() async {
    readCalls++;
    return 0;
  }

  @override
  Future<List<int>> getWeeklyReadingMinutes() async {
    readCalls++;
    return List.filled(7, 0);
  }

  @override
  Future<int> getCurrentStreak() async {
    readCalls++;
    return 0;
  }

  @override
  Future<int> getLongestStreak() async {
    readCalls++;
    return 0;
  }
}

/// 実 Hive の box を返す最小 BoxManager（startSession のローカル退避経路用）
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
    final dir = await Directory.systemTemp.createTemp('derived_invalidation');
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

  group('readingDerivedInvalidatorProvider（単一窓口）', () {
    ({ProviderContainer container, Map<String, int> counts}) build() {
      final counts = <String, int>{'habit': 0, 'weekly': 0};
      final container = ProviderContainer(
        overrides: [
          readingHabitSessionsProvider.overrideWith((ref) async {
            counts['habit'] = counts['habit']! + 1;
            return <ReadingSession>[];
          }),
          weeklyReadingMinutesProvider.overrideWith((ref) async {
            counts['weekly'] = counts['weekly']! + 1;
            return List<int>.filled(7, 0);
          }),
        ],
      );
      return (container: container, counts: counts);
    }

    test('窓口を呼ぶと両Providerが再評価される', () async {
      final ctx = build();
      addTearDown(ctx.container.dispose);

      await ctx.container.read(readingHabitSessionsProvider.future);
      await ctx.container.read(weeklyReadingMinutesProvider.future);
      expect(ctx.counts, {'habit': 1, 'weekly': 1});

      ctx.container.read(readingDerivedInvalidatorProvider)();

      await ctx.container.read(readingHabitSessionsProvider.future);
      await ctx.container.read(weeklyReadingMinutesProvider.future);
      expect(ctx.counts, {'habit': 2, 'weekly': 2},
          reason: '窓口はヒートマップ用・週間グラフ用の両Providerを落とすべき');
    });

    test('窓口を呼ばなければ再評価されない（アブレーションの対照）', () async {
      final ctx = build();
      addTearDown(ctx.container.dispose);

      await ctx.container.read(readingHabitSessionsProvider.future);
      await ctx.container.read(weeklyReadingMinutesProvider.future);
      // 何も落とさずに再読 → キャッシュが返る
      await ctx.container.read(readingHabitSessionsProvider.future);
      await ctx.container.read(weeklyReadingMinutesProvider.future);

      expect(ctx.counts, {'habit': 1, 'weekly': 1},
          reason: '非autoDispose の FutureProvider は invalidate しない限り再評価されない');
    });
  });

  group('FallbackReadingSessionRepository.onSuccessfulWrite', () {
    test('createSession 成功で1回呼ばれる', () async {
      var calls = 0;
      final repo = FallbackReadingSessionRepository(
        primary: _FakeRepo(),
        local: _FakeRepo(),
        boxManager: _HiveBoxManager(),
        onSuccessfulWrite: () => calls++,
      );

      final created = await repo.createSession(_session('s-1'));

      expect(created.id, 's-1');
      expect(calls, 1);
    });

    test('createSession 失敗時は呼ばれず例外が伝播する', () async {
      var calls = 0;
      final repo = FallbackReadingSessionRepository(
        primary: _FakeRepo(throwOnWrite: true),
        local: _FakeRepo(),
        boxManager: _HiveBoxManager(),
        onSuccessfulWrite: () => calls++,
      );

      await expectLater(repo.createSession(_session('s-2')), throwsException);
      expect(calls, 0, reason: '失敗時は派生Providerを落としてはいけない');
    });

    test('startSession がプライマリ失敗→ローカル退避成功で1回呼ばれる', () async {
      var calls = 0;
      final repo = FallbackReadingSessionRepository(
        primary: _FakeRepo(throwOnWrite: true),
        local: _FakeRepo(),
        boxManager: _HiveBoxManager(),
        onSuccessfulWrite: () => calls++,
      );

      final session = await repo.startSession('ub-1', 0);

      expect(session.id.startsWith('local:'), isTrue);
      expect(calls, 1, reason: 'ローカル退避も書き込み成功なので窓口を叩く');
    });

    test('startSession 成功（プライマリ）で1回呼ばれる', () async {
      var calls = 0;
      final repo = FallbackReadingSessionRepository(
        primary: _FakeRepo(),
        local: _FakeRepo(),
        boxManager: _HiveBoxManager(),
        onSuccessfulWrite: () => calls++,
      );

      await repo.startSession('ub-1', 0);

      expect(calls, 1);
    });

    test('endSession 成功で1回呼ばれる（リモート/local: 双方）', () async {
      var calls = 0;
      final repo = FallbackReadingSessionRepository(
        primary: _FakeRepo(),
        local: _FakeRepo(),
        boxManager: _HiveBoxManager(),
        onSuccessfulWrite: () => calls++,
      );

      await repo.endSession('remote-1', 10, 5);
      expect(calls, 1);

      await repo.endSession('local:remote-2', 10, 5);
      expect(calls, 2);
    });

    test('updateSession 成功で1回呼ばれる（リモート/local: 双方）', () async {
      var calls = 0;
      final repo = FallbackReadingSessionRepository(
        primary: _FakeRepo(),
        local: _FakeRepo(),
        boxManager: _HiveBoxManager(),
        onSuccessfulWrite: () => calls++,
      );

      await repo.updateSession(_session('remote-1'));
      expect(calls, 1);

      await repo.updateSession(_session('local:remote-1'));
      expect(calls, 2);
    });

    test('deleteSession 成功で1回呼ばれる（リモート/local: 双方）', () async {
      var calls = 0;
      final repo = FallbackReadingSessionRepository(
        primary: _FakeRepo(),
        local: _FakeRepo(),
        boxManager: _HiveBoxManager(),
        onSuccessfulWrite: () => calls++,
      );

      await repo.deleteSession('remote-1');
      expect(calls, 1);

      await repo.deleteSession('local:remote-1');
      expect(calls, 2);
    });

    test('失敗する書き込みでは呼ばれない（update/delete/end）', () async {
      var calls = 0;
      final repo = FallbackReadingSessionRepository(
        primary: _FakeRepo(throwOnWrite: true),
        local: _FakeRepo(throwOnWrite: true),
        boxManager: _HiveBoxManager(),
        onSuccessfulWrite: () => calls++,
      );

      await expectLater(repo.endSession('remote-1', 1, 1), throwsException);
      await expectLater(
          repo.updateSession(_session('remote-1')), throwsException);
      await expectLater(repo.deleteSession('remote-1'), throwsException);
      expect(calls, 0);
    });

    test('読み取り系メソッドでは一度も呼ばれない', () async {
      var calls = 0;
      final primary = _FakeRepo();
      final repo = FallbackReadingSessionRepository(
        primary: primary,
        local: _FakeRepo(),
        boxManager: _HiveBoxManager(),
        onSuccessfulWrite: () => calls++,
      );

      await repo.getByUserBook('ub-1');
      await repo.getRecentSessions(limit: 5);
      await repo.getAllReadingDates();
      await repo.getTotalReadingMinutes('ub-1');
      await repo.getTotalReadingMinutesAll();
      await repo.getTotalPagesReadAll();
      await repo.getWeeklyReadingMinutes();
      await repo.getCurrentStreak();
      await repo.getLongestStreak();

      expect(calls, 0);
      expect(primary.readCalls, greaterThan(0), reason: '読み取りが実際に走っている前提');
    });

    test('コールバックが throw しても書き込み結果は壊れない', () async {
      final repo = FallbackReadingSessionRepository(
        primary: _FakeRepo(),
        local: _FakeRepo(),
        boxManager: _HiveBoxManager(),
        onSuccessfulWrite: () => throw StateError('callback broke'),
      );

      final created = await repo.createSession(_session('s-3', minutes: 42));
      expect(created.id, 's-3');
      expect(created.durationMinutes, 42);

      await repo.endSession('remote-1', 7, 9);
      await repo.deleteSession('remote-2');
    });

    test('フック未指定（既存呼出）でも従来通り動作する', () async {
      final repo = FallbackReadingSessionRepository(
        primary: _FakeRepo(),
        local: _FakeRepo(),
        boxManager: _HiveBoxManager(),
      );

      final created = await repo.createSession(_session('s-4'));
      expect(created.id, 's-4');
    });
  });
}
