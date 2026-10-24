import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/adventurer_progress.dart';
import 'package:tsundoku_quest/domain/models/adventurer_stats.dart';
import 'package:tsundoku_quest/domain/repositories/adventurer_repository.dart';
import 'package:tsundoku_quest/features/shared/data/adventurer_progress_repository.dart';
import 'package:tsundoku_quest/shared/providers/adventurer_provider.dart';

/// サーバ統計を固定で返す偽リポジトリ（level/xp は常に初期値）
class _FakeAdventurerRepository implements AdventurerRepository {
  _FakeAdventurerRepository({this.throwOnStats = false});

  final bool throwOnStats;

  @override
  Future<AdventurerStats> stats() async {
    if (throwOnStats) throw StateError('offline');
    return AdventurerStats(
      level: 1,
      xp: 0,
      xpToNextLevel: 100,
      title: '書庫の見習い',
      totalBooksRegistered: 12,
      totalBooksCompleted: 4,
      totalReadingMinutes: 900,
      totalPagesRead: 1500,
      currentStreak: 3,
      longestStreak: 9,
      readingDates: const ['2026-10-01'],
    );
  }

  @override
  Future<void> addXp(int amount) async {}

  @override
  Future<void> updateReadingStats(int pagesRead, int minutesRead) async {}

  @override
  Future<void> incrementBooksRegistered() async {}

  @override
  Future<void> incrementBooksCompleted() async {}

  @override
  Future<void> updateStreak() async {}
}

void main() {
  group('AdventurerNotifier 復元', () {
    test('保存済みの積み上げを state へ復元する', () async {
      final repository = InMemoryAdventurerProgressRepository(
        initial: const AdventurerProgress(
          level: 9,
          xp: 400,
          xpToNextLevel: 800,
          title: '知の航海者',
          readingDates: ['2026-10-02'],
        ),
      );
      final notifier = AdventurerNotifier(progressRepository: repository);

      await notifier.loadProgress();

      expect(notifier.state.level, 9);
      expect(notifier.state.xp, 400);
      expect(notifier.state.title, '知の航海者');
      expect(notifier.state.readingDates, ['2026-10-02']);
    });

    test('リポジトリ未指定なら何もしない（既定は見習い）', () async {
      final notifier = AdventurerNotifier();

      await notifier.loadProgress();

      expect(notifier.state.level, 1);
      expect(notifier.state.xp, 0);
    });

    test('壊れたリポジトリでも例外を漏らさない', () async {
      final notifier =
          AdventurerNotifier(progressRepository: _ThrowingProgressRepository());

      await expectLater(notifier.loadProgress(), completes);
      expect(notifier.state.level, 1);
    });
  });

  group('AdventurerNotifier 永続化', () {
    test('addXp は保存まで到達する（state 更新だけで終わらない）', () async {
      final repository = InMemoryAdventurerProgressRepository();
      final notifier = AdventurerNotifier(progressRepository: repository);

      notifier.addXp(150);
      await Future<void>.delayed(Duration.zero);

      expect(repository.saveCount, 1);
      expect(repository.current.level, notifier.state.level);
      expect(repository.current.xp, notifier.state.xp);
      expect(repository.current.title, notifier.state.title);
      expect(repository.current.level, 2);
    });

    test('addReadingDate は保存まで到達する', () async {
      final repository = InMemoryAdventurerProgressRepository();
      final notifier = AdventurerNotifier(progressRepository: repository);

      notifier.addReadingDate('2026-10-08T12:00:00Z');
      await Future<void>.delayed(Duration.zero);

      expect(repository.saveCount, 1);
      expect(repository.current.readingDates, ['2026-10-08']);
    });

    test('既にある読書日を足しても保存は発生しない', () async {
      final repository = InMemoryAdventurerProgressRepository(
        initial: const AdventurerProgress(
          level: 1,
          xp: 0,
          xpToNextLevel: 100,
          title: '書庫の見習い',
          readingDates: ['2026-10-08'],
        ),
      );
      final notifier = AdventurerNotifier(progressRepository: repository);
      await notifier.loadProgress();

      notifier.addReadingDate('2026-10-08');
      await Future<void>.delayed(Duration.zero);

      expect(repository.saveCount, 0);
    });
  });

  group('再起動をまたぐ合成（親探針）', () {
    test('再起動後もレベル・称号が保たれる（見習いに戻らない）', () async {
      final repository = InMemoryAdventurerProgressRepository();

      // 1回目の起動: 復元→加算→保存
      final first = AdventurerNotifier(progressRepository: repository);
      await first.loadProgress();
      first.addXp(2000);
      await Future<void>.delayed(Duration.zero);
      final levelBeforeRestart = first.state.level;
      expect(levelBeforeRestart, 5);

      // 2回目の起動: 新しい notifier が同じリポジトリから復元する
      final second = AdventurerNotifier(progressRepository: repository);
      await second.loadProgress();

      expect(second.state.level, levelBeforeRestart);
      expect(second.state.title, '本の探検家');
    });

    test('サーバ統計を重ねてもローカルのレベルを失わない（本禍津の再現）', () async {
      final repository = InMemoryAdventurerProgressRepository(
        initial: const AdventurerProgress(
          level: 8,
          xp: 120,
          xpToNextLevel: 700,
          title: '知の航海者',
          readingDates: ['2026-10-04'],
        ),
      );
      final notifier = AdventurerNotifier(progressRepository: repository);
      await notifier.loadProgress();

      notifier.loadFromRepository(_FakeAdventurerRepository());
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.level, 8);
      expect(notifier.state.title, '知の航海者');
      expect(notifier.state.totalBooksRegistered, 12);
      expect(notifier.state.currentStreak, 3);
      expect(notifier.state.readingDates, ['2026-10-01', '2026-10-04']);
    });

    test('オフライン（サーバ取得失敗）でも積み上げを失わない', () async {
      final repository = InMemoryAdventurerProgressRepository(
        initial: const AdventurerProgress(
          level: 6,
          xp: 50,
          xpToNextLevel: 600,
          title: '本の探検家',
          readingDates: [],
        ),
      );
      final notifier = AdventurerNotifier(progressRepository: repository);
      await notifier.loadProgress();

      notifier.loadFromRepository(_FakeAdventurerRepository(throwOnStats: true));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.level, 6);
      expect(notifier.state.xp, 50);
      expect(notifier.state.errorMessage, isNotNull);
    });
  });
}

class _ThrowingProgressRepository implements AdventurerProgressRepository {
  @override
  Future<AdventurerProgress> load() async {
    throw StateError('broken storage');
  }

  @override
  Future<void> save(AdventurerProgress progress) async {
    throw StateError('broken storage');
  }
}
