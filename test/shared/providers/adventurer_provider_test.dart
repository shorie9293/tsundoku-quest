import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/shared/providers/adventurer_provider.dart';

void main() {
  group('AdventurerNotifier', () {
    test('initial state is beginner', () {
      final notifier = AdventurerNotifier();
      final state = notifier.state;

      expect(state.level, 1);
      expect(state.xp, 0);
      expect(state.xpToNextLevel, 100);
      expect(state.title, '書庫の見習い');
      expect(state.totalBooksRegistered, 0);
      expect(state.totalBooksCompleted, 0);
      expect(state.currentStreak, 0);
    });

    group('addXp', () {
      test('should add XP and keep level 1 under 100 XP', () {
        final notifier = AdventurerNotifier();
        notifier.addXp(50);
        expect(notifier.state.xp, 50);
        expect(notifier.state.level, 1);
      });

      test('should level up when XP exceeds threshold', () {
        final notifier = AdventurerNotifier();
        notifier.addXp(120); // crosses 100 threshold → level 2
        expect(notifier.state.level, 2);
        expect(notifier.state.title, '書庫の見習い'); // level 2 はまだ「見習い」
      });

      test('should reach level 5 with enough XP', () {
        final notifier = AdventurerNotifier();
        notifier.addXp(2000); // 2000 XP → level 5
        expect(notifier.state.level, 5);
        expect(notifier.state.title, '本の探検家');
      });
    });

    group('incrementBooks', () {
      test('should increment registered count', () {
        final notifier = AdventurerNotifier();
        notifier.incrementBooksRegistered();
        notifier.incrementBooksRegistered();
        expect(notifier.state.totalBooksRegistered, 2);
      });

      test('should increment completed count', () {
        final notifier = AdventurerNotifier();
        notifier.incrementBooksCompleted();
        expect(notifier.state.totalBooksCompleted, 1);
      });
    });

    group('updateReadingStats', () {
      test('should accumulate reading minutes and pages', () {
        final notifier = AdventurerNotifier();
        notifier.updateReadingStats(minutes: 30, pages: 15);
        notifier.updateReadingStats(minutes: 45, pages: 20);
        expect(notifier.state.totalReadingMinutes, 75);
        expect(notifier.state.totalPagesRead, 35);
      });
    });

    group('readingDates', () {
      test('should start with empty readingDates', () {
        final notifier = AdventurerNotifier();
        expect(notifier.state.readingDates, isEmpty);
      });

      test('should add reading date', () {
        final notifier = AdventurerNotifier();
        notifier.addReadingDate('2026-05-06');
        expect(notifier.state.readingDates, contains('2026-05-06'));
      });

      test('should not add duplicate dates', () {
        final notifier = AdventurerNotifier();
        notifier.addReadingDate('2026-05-06');
        notifier.addReadingDate('2026-05-06');
        expect(notifier.state.readingDates.length, 1);
      });
    });

    group('updateStreak', () {
      test('should update both current and longest streaks', () {
        final notifier = AdventurerNotifier();
        notifier.updateStreak(current: 7, longest: 7);
        expect(notifier.state.currentStreak, 7);
        expect(notifier.state.longestStreak, 7);
      });

      test('should keep longest streak even when current drops', () {
        final notifier = AdventurerNotifier();
        notifier.updateStreak(current: 14, longest: 14);
        notifier.updateStreak(current: 0, longest: 14);
        expect(notifier.state.currentStreak, 0);
        expect(notifier.state.longestStreak, 14);
      });
    });
  });
}
