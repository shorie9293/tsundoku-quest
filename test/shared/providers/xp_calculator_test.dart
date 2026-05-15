import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/shared/providers/xp_calculator.dart';

void main() {
  group('calculateXp', () {
    test('daily_quest should return 50 XP', () {
      expect(calculateXp(type: 'daily_quest'), 50);
    });

    test('complete_book should return 200 + pages XP', () {
      expect(calculateXp(type: 'complete_book', pages: 300), 500);
    });

    test('complete_book with null pages should return 200 XP', () {
      expect(calculateXp(type: 'complete_book'), 200);
    });

    test('reading_session should return minutes * 2 XP', () {
      expect(calculateXp(type: 'reading_session', minutes: 15), 30);
    });

    test('reading_session with null minutes should return 0 XP', () {
      expect(calculateXp(type: 'reading_session'), 0);
    });

    test('write_trophy should return 100 XP', () {
      expect(calculateXp(type: 'write_trophy'), 100);
    });

    test('unknown type should return 0 XP', () {
      expect(calculateXp(type: 'unknown'), 0);
    });
  });

  group('calculateLevel', () {
    test('level 1 with 0 XP', () {
      final result = calculateLevel(0);
      expect(result.level, 1);
      expect(result.xp, 0);
      expect(result.xpToNextLevel, 100);
      expect(result.title, '書庫の見習い');
    });

    test('level 1 with 50 XP', () {
      final result = calculateLevel(50);
      expect(result.level, 1);
      expect(result.xp, 50);
      expect(result.xpToNextLevel, 100);
    });

    test('level 2 with 150 XP', () {
      final result = calculateLevel(150);
      expect(result.level, 2);
      expect(result.xp, 50); // 150 - 100 = 50 (level 1 cost)
      expect(result.xpToNextLevel, 300); // 400 - 100 = 300
    });

    test('level 5 with 2000 XP', () {
      final result = calculateLevel(2000);
      expect(result.level, 5);
      expect(result.title, '本の探検家');
    });

    test('level 10 with 8500 XP', () {
      final result = calculateLevel(8500);
      expect(result.level, 10);
      expect(result.title, '知の航海者');
    });

    test('level 20 with 37000 XP', () {
      final result = calculateLevel(37000);
      expect(result.level, 20);
      expect(result.title, '書庫の賢者');
    });

    test('level 30 with 85000 XP', () {
      final result = calculateLevel(85000);
      expect(result.level, 30);
      expect(result.title, '千巻の守護者');
    });

    test('level 50 with 240200 XP', () {
      final result = calculateLevel(240200);
      expect(result.level, 50);
      expect(result.title, '万巻の覇王');
    });
  });
}
