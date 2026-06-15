import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/enemy.dart';
import 'package:tsundoku_quest/shared/providers/enemy_provider.dart';

/// Helper: create a test enemy with given rank
Enemy _testEnemy(String id, int rank) => Enemy(
      id: id,
      name: '敵 $id',
      rank: rank,
      hp: 10 * rank,
      attack: 2 * rank,
      defense: 1 * rank,
      xpReward: 5 * rank,
      spriteUrl: 'https://example.com/enemy_$id.png',
    );

void main() {
  group('EnemySelector.selectRandom', () {
    test('returns null for empty list', () {
      final selector = EnemySelector();
      expect(selector.selectRandom([]), isNull);
    });

    test('returns the only enemy from single-element list', () {
      final selector = EnemySelector();
      final enemy = _testEnemy('e1', 1);
      final result = selector.selectRandom([enemy]);
      expect(result, enemy);
    });

    test('returns an enemy from list (multiple enemies)', () {
      final selector = EnemySelector(random: Random(42)); // seeded
      final enemies = [
        _testEnemy('e1', 1),
        _testEnemy('e2', 2),
        _testEnemy('e3', 3),
      ];
      final result = selector.selectRandom(enemies);
      expect(result, isNotNull);
      expect(enemies, contains(result));
    });

    group('playerLevel filtering', () {
      test('level 2 player only gets rank 1-2 enemies', () {
        final selector = EnemySelector(random: Random(42));
        final enemies = [
          _testEnemy('e1', 1),
          _testEnemy('e2', 2),
          _testEnemy('e3', 3), // should be filtered out
          _testEnemy('e4', 4), // should be filtered out
          _testEnemy('e5', 5), // should be filtered out
        ];

        // Run 100 times, ensure rank 3+ never appears
        for (int i = 0; i < 100; i++) {
          final result = selector.selectRandom(enemies, playerLevel: 2);
          expect(result, isNotNull);
          expect(result!.rank, lessThanOrEqualTo(2));
        }
      });

      test('level 5 player only gets rank 1-3 enemies', () {
        final selector = EnemySelector(random: Random(99));
        final enemies = [
          _testEnemy('e1', 1),
          _testEnemy('e2', 2),
          _testEnemy('e3', 3),
          _testEnemy('e4', 4), // should be filtered out
          _testEnemy('e5', 5), // should be filtered out
        ];

        for (int i = 0; i < 100; i++) {
          final result = selector.selectRandom(enemies, playerLevel: 5);
          expect(result, isNotNull);
          expect(result!.rank, lessThanOrEqualTo(3));
        }
      });

      test('level 10 player only gets rank 1-4 enemies', () {
        final selector = EnemySelector(random: Random(77));
        final enemies = [
          _testEnemy('e1', 1),
          _testEnemy('e2', 2),
          _testEnemy('e3', 3),
          _testEnemy('e4', 4),
          _testEnemy('e5', 5), // should be filtered out
        ];

        for (int i = 0; i < 100; i++) {
          final result = selector.selectRandom(enemies, playerLevel: 10);
          expect(result, isNotNull);
          expect(result!.rank, lessThanOrEqualTo(4));
        }
      });

      test('level 20 player can get any rank (level > 15)', () {
        final selector = EnemySelector(random: Random(123));
        final enemies = [
          _testEnemy('e1', 1),
          _testEnemy('e2', 2),
          _testEnemy('e3', 3),
          _testEnemy('e4', 4),
          _testEnemy('e5', 5),
        ];
        final seenRanks = <int>{};

        for (int i = 0; i < 500; i++) {
          final result = selector.selectRandom(enemies, playerLevel: 20);
          expect(result, isNotNull);
          seenRanks.add(result!.rank);
        }

        // Should see all ranks with enough trials
        expect(seenRanks, containsAll([1, 2, 3, 4, 5]));
      });

      test('returns null when all enemies are above player level', () {
        final selector = EnemySelector();
        final enemies = [
          _testEnemy('e3', 3),
          _testEnemy('e4', 4),
          _testEnemy('e5', 5),
        ];

        final result = selector.selectRandom(enemies, playerLevel: 1);
        expect(result, isNull);
      });
    });

    group('weighting', () {
      test('rank 1 appears more often than rank 5 (statistical test)',
          () {
        final selector = EnemySelector(random: Random(42));
        final enemies = [
          _testEnemy('e1', 1),
          _testEnemy('e5', 5),
        ];

        int rank1Count = 0;
        int rank5Count = 0;
        const trials = 1000;

        for (int i = 0; i < trials; i++) {
          final result = selector.selectRandom(enemies);
          if (result!.rank == 1) {
            rank1Count++;
          } else if (result.rank == 5) {
            rank5Count++;
          }
        }

        // rank 1 weight = 5, rank 5 weight = 1
        // expected ratio roughly 5:1
        expect(rank1Count + rank5Count, trials);
        expect(rank1Count, greaterThan(rank5Count));
        // With 1000 trials, rank 1 should appear at least 70% of the time
        // (5/6 ≈ 83%, give some margin)
        expect(rank1Count, greaterThan(trials * 0.7));
      });

      test('lower ranks are weighted higher in general', () {
        final selector = EnemySelector(random: Random(7));
        final enemies = [
          _testEnemy('e1', 1),
          _testEnemy('e2', 2),
          _testEnemy('e3', 3),
          _testEnemy('e4', 4),
          _testEnemy('e5', 5),
        ];

        final counts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
        const trials = 1000;

        for (int i = 0; i < trials; i++) {
          final result = selector.selectRandom(enemies)!;
          counts[result.rank] = counts[result.rank]! + 1;
        }

        // rank 1 (weight 5) should be most common
        // rank 5 (weight 1) should be least common
        expect(counts[1]!, greaterThan(counts[2]!));
        expect(counts[2]!, greaterThan(counts[3]!));
        expect(counts[3]!, greaterThan(counts[4]!));
        expect(counts[4]!, greaterThan(counts[5]!));
      });
    });

    test('without playerLevel all enemies are candidates', () {
      final selector = EnemySelector(random: Random(42));
      final enemies = [
        _testEnemy('e1', 1),
        _testEnemy('e5', 5),
      ];
      final seenRanks = <int>{};

      for (int i = 0; i < 100; i++) {
        final result = selector.selectRandom(enemies);
        seenRanks.add(result!.rank);
      }

      // Both ranks should appear
      expect(seenRanks, containsAll([1, 5]));
    });

    test('seed 0 produces deterministic results', () {
      final selector1 = EnemySelector(random: Random(0));
      final selector2 = EnemySelector(random: Random(0));
      final enemies = [
        _testEnemy('e1', 1),
        _testEnemy('e2', 2),
        _testEnemy('e3', 3),
      ];

      final results1 = List.generate(10, (_) => selector1.selectRandom(enemies)!.id);
      final results2 = List.generate(10, (_) => selector2.selectRandom(enemies)!.id);

      expect(results1, results2);
    });
  });
}
