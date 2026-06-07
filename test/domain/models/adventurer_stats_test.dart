import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/adventurer_stats.dart';

void main() {
  group('AdventurerStats', () {
    group('constructor', () {
      test('全フィールドが正しく設定される', () {
        const stats = AdventurerStats(
          level: 5,
          xp: 250,
          xpToNextLevel: 500,
          title: '書庫の探検家',
          totalBooksRegistered: 10,
          totalBooksCompleted: 3,
          totalReadingMinutes: 120,
          totalPagesRead: 450,
          currentStreak: 7,
          longestStreak: 14,
          readingDates: ['2026-05-01', '2026-05-02'],
        );

        expect(stats.level, 5);
        expect(stats.xp, 250);
        expect(stats.xpToNextLevel, 500);
        expect(stats.title, '書庫の探検家');
        expect(stats.totalBooksRegistered, 10);
        expect(stats.totalBooksCompleted, 3);
        expect(stats.totalReadingMinutes, 120);
        expect(stats.totalPagesRead, 450);
        expect(stats.currentStreak, 7);
        expect(stats.longestStreak, 14);
        expect(stats.readingDates, ['2026-05-01', '2026-05-02']);
      });
    });

    group('beginner factory', () {
      test('正しい初期値を持つインスタンスを返す', () {
        final stats = AdventurerStats.beginner();

        expect(stats.level, 1);
        expect(stats.xp, 0);
        expect(stats.xpToNextLevel, 100);
        expect(stats.title, '書庫の見習い');
        expect(stats.totalBooksRegistered, 0);
        expect(stats.totalBooksCompleted, 0);
        expect(stats.totalReadingMinutes, 0);
        expect(stats.totalPagesRead, 0);
        expect(stats.currentStreak, 0);
        expect(stats.longestStreak, 0);
        expect(stats.readingDates, isEmpty);
      });
    });

    group('equality', () {
      test('同一値のconstインスタンスが等価である', () {
        const stats1 = AdventurerStats(
          level: 3,
          xp: 100,
          xpToNextLevel: 300,
          title: '本の守護者',
          totalBooksRegistered: 5,
          totalBooksCompleted: 2,
          totalReadingMinutes: 60,
          totalPagesRead: 200,
          currentStreak: 3,
          longestStreak: 10,
          readingDates: ['2026-05-15'],
        );
        const stats2 = AdventurerStats(
          level: 3,
          xp: 100,
          xpToNextLevel: 300,
          title: '本の守護者',
          totalBooksRegistered: 5,
          totalBooksCompleted: 2,
          totalReadingMinutes: 60,
          totalPagesRead: 200,
          currentStreak: 3,
          longestStreak: 10,
          readingDates: ['2026-05-15'],
        );

        expect(stats1, equals(stats2));
        expect(stats1.hashCode, stats2.hashCode);
      });

      test('異なる値のインスタンスは等価でない', () {
        final stats1 = AdventurerStats.beginner();
        const stats2 = AdventurerStats(
          level: 2,
          xp: 0,
          xpToNextLevel: 100,
          title: '書庫の見習い',
          totalBooksRegistered: 0,
          totalBooksCompleted: 0,
          totalReadingMinutes: 0,
          totalPagesRead: 0,
          currentStreak: 0,
          longestStreak: 0,
          readingDates: [],
        );

        expect(stats1, isNot(equals(stats2)));
      });
    });

    group('immutability', () {
      test('readingDates が変更不可 (add()でエラー)', () {
        final stats = AdventurerStats.beginner();

        expect(
          () => stats.readingDates.add('2026-05-21'),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });
  });
}
