import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/adventurer_progress.dart';
import 'package:tsundoku_quest/domain/models/adventurer_stats.dart';

AdventurerStats _serverStats({
  int books = 12,
  int completed = 4,
  int minutes = 900,
  int pages = 1500,
  int streak = 3,
  int longest = 9,
  List<String> dates = const ['2026-10-01'],
}) {
  return AdventurerStats(
    level: 1,
    xp: 0,
    xpToNextLevel: 100,
    title: '書庫の見習い',
    totalBooksRegistered: books,
    totalBooksCompleted: completed,
    totalReadingMinutes: minutes,
    totalPagesRead: pages,
    currentStreak: streak,
    longestStreak: longest,
    readingDates: dates,
  );
}

void main() {
  group('AdventurerProgress.toJson/fromJson', () {
    test('往復で値が一致する', () {
      const progress = AdventurerProgress(
        level: 7,
        xp: 250,
        xpToNextLevel: 600,
        title: '知の航海者',
        readingDates: ['2026-10-01', '2026-10-02'],
      );

      final restored = AdventurerProgress.fromJson(progress.toJson());

      expect(restored, progress);
      expect(restored.title, '知の航海者');
      expect(restored.readingDates, ['2026-10-01', '2026-10-02']);
    });

    test('破損・欠損キーは既定値へフォールバックする（例外を投げない）', () {
      final restored = AdventurerProgress.fromJson(<String, dynamic>{
        'level': 'abc',
        'xp': -50,
        'xpToNextLevel': 0,
        'title': '',
        'readingDates': ['2026-10-03T10:00:00Z', 42, null],
      });

      expect(restored.level, 1);
      expect(restored.xp, 0);
      expect(restored.xpToNextLevel, 100);
      expect(restored.title, '書庫の見習い');
      expect(restored.readingDates, ['2026-10-03']);
    });

    test('数値が num/String で来ても読める', () {
      final restored = AdventurerProgress.fromJson(<String, dynamic>{
        'level': 5,
        'xp': '120',
        'xpToNextLevel': 300,
        'title': '本の探検家',
      });

      expect(restored.level, 5);
      expect(restored.xp, 120);
      expect(restored.readingDates, isEmpty);
    });
  });

  group('AdventurerProgress.fromStats', () {
    test('永続化対象だけを抜き出し日付を正規化する', () {
      final stats = _serverStats(
        books: 3,
        minutes: 100,
        dates: const ['2026-10-02T09:00:00', '2026-10-01'],
      );
      final progress = AdventurerProgress.fromStats(stats);

      expect(progress.level, 1);
      expect(progress.xp, 0);
      expect(progress.readingDates, ['2026-10-01', '2026-10-02']);
    });
  });

  group('AdventurerProgress.applyTo', () {
    test('ローカルの積み上げを保持しサーバ統計を維持する', () {
      const local = AdventurerProgress(
        level: 7,
        xp: 250,
        xpToNextLevel: 600,
        title: '知の航海者',
        readingDates: ['2026-10-05'],
      );

      final merged = local.applyTo(_serverStats());

      expect(merged.level, 7);
      expect(merged.xp, 250);
      expect(merged.title, '知の航海者');
      expect(merged.totalBooksRegistered, 12);
      expect(merged.totalBooksCompleted, 4);
      expect(merged.totalReadingMinutes, 900);
      expect(merged.totalPagesRead, 1500);
      expect(merged.currentStreak, 3);
      expect(merged.longestStreak, 9);
      expect(merged.readingDates, ['2026-10-01', '2026-10-05']);
    });

    test('読書日は重複させない', () {
      const local = AdventurerProgress(
        level: 2,
        xp: 10,
        xpToNextLevel: 200,
        title: '書庫の見習い',
        readingDates: ['2026-10-01'],
      );

      final merged = local.applyTo(_serverStats(dates: const ['2026-10-01']));

      expect(merged.readingDates, ['2026-10-01']);
    });
  });

  group('normalizeReadingDates', () {
    test('先頭10文字・空除去・重複除去・昇順', () {
      final result = AdventurerProgress.normalizeReadingDates([
        '2026-10-03T21:00:00Z',
        '2026-10-01',
        '',
        '2026-10-03',
      ]);

      expect(result, ['2026-10-01', '2026-10-03']);
    });
  });
}
