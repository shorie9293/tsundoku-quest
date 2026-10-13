import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/badges/domain/badge_definition.dart';

BadgeDefinition _def({int threshold = 7}) {
  return BadgeDefinition(
    id: 'test_badge',
    name: '試練の証',
    description: 'テスト用バッジ',
    icon: '🏅',
    category: BadgeCategory.streak,
    tier: 2,
    threshold: threshold,
    metricKey: 'currentStreak',
  );
}

void main() {
  group('BadgeCategory', () {
    test('5カテゴリが label と icon を持つ', () {
      expect(BadgeCategory.completedBooks.label, '読了冊数');
      expect(BadgeCategory.completedBooks.icon, '📚');
      expect(BadgeCategory.streak.label, '連続記録');
      expect(BadgeCategory.streak.icon, '🔥');
      expect(BadgeCategory.readingTime.label, '読書時間');
      expect(BadgeCategory.readingTime.icon, '⏱️');
      expect(BadgeCategory.pagesTotal.label, '読了ページ');
      expect(BadgeCategory.pagesTotal.icon, '📄');
      expect(BadgeCategory.timeOfDay.label, '読書の時間帯');
      expect(BadgeCategory.timeOfDay.icon, '🌅');
    });
  });

  group('BadgeProgress', () {
    test('ratio は current/required', () {
      final p = BadgeProgress(
        definition: _def(threshold: 10),
        current: 4,
        isEarned: false,
      );
      expect(p.ratio, closeTo(0.4, 1e-9));
    });

    test('ratio は current > required で 1.0 にクランプ', () {
      final p = BadgeProgress(
        definition: _def(threshold: 10),
        current: 15,
        isEarned: true,
      );
      expect(p.ratio, 1.0);
      expect(p.percent, 100);
      expect(p.remaining, 0);
    });

    test('ratio は負にならず 0.0', () {
      final p = BadgeProgress(
        definition: _def(threshold: 10),
        current: 0,
        isEarned: false,
      );
      expect(p.ratio, 0.0);
      expect(p.percent, 0);
    });

    test('percent は四捨五入', () {
      final p = BadgeProgress(
        definition: _def(threshold: 3),
        current: 2,
        isEarned: false,
      );
      expect((p.ratio * 100).round(), p.percent);
      expect(p.percent, 67); // 2/3 = 66.67
    });

    test('remaining は残り目標', () {
      final p = BadgeProgress(
        definition: _def(threshold: 7),
        current: 3,
        isEarned: false,
      );
      expect(p.remaining, 4);
    });

    test('progressLabel は min(current,required) / required 形式', () {
      expect(
        BadgeProgress(
          definition: _def(threshold: 7),
          current: 3,
          isEarned: false,
        ).progressLabel,
        '3 / 7',
      );
      expect(
        BadgeProgress(
          definition: _def(threshold: 7),
          current: 12,
          isEarned: true,
        ).progressLabel,
        '7 / 7',
      );
    });

    test('isEarned と current の関係は service 側で決める（ここでは保持のみ）', () {
      final p = BadgeProgress(
        definition: _def(),
        current: 3,
        isEarned: true,
        earnedAt: DateTime(2026, 10, 13),
      );
      expect(p.isEarned, true);
      expect(p.earnedAt, DateTime(2026, 10, 13));
    });

    test('copyWith は earnedAt のみ差し替える', () {
      final p = BadgeProgress(
        definition: _def(),
        current: 7,
        isEarned: true,
      );
      expect(p.earnedAt, isNull);

      final earned = p.copyWith(earnedAt: DateTime(2026, 1, 2, 3, 4));
      expect(earned.earnedAt, DateTime(2026, 1, 2, 3, 4));
      expect(earned.definition, same(p.definition));
      expect(earned.current, p.current);
      expect(earned.isEarned, p.isEarned);

      final cleared = earned.copyWith(earnedAt: null);
      expect(cleared.earnedAt, isNull);
      expect(earned.earnedAt, isNotNull); // 元は不変
    });

    test('threshold <= 0 で ArgumentError', () {
      expect(() => _def(threshold: 0), throwsArgumentError);
      expect(() => _def(threshold: -1), throwsArgumentError);
    });
  });

  group('BadgeCollection', () {
    BadgeProgress _bp(String id, int current, int threshold, bool earned) {
      return BadgeProgress(
        definition: BadgeDefinition(
          id: id,
          name: id,
          description: id,
          icon: '🏅',
          category: BadgeCategory.streak,
          tier: 1,
          threshold: threshold,
          metricKey: 'currentStreak',
        ),
        current: current,
        isEarned: earned,
      );
    }

    test('earnedCount / total / summaryLabel / completionRatio', () {
      final c = BadgeCollection([
        _bp('a', 1, 1, true),
        _bp('b', 2, 5, false),
        _bp('c', 5, 5, true),
        _bp('d', 0, 3, false),
      ]);
      expect(c.total, 4);
      expect(c.earnedCount, 2);
      expect(c.summaryLabel, '獲得 2 / 4');
      expect(c.completionRatio, closeTo(0.5, 1e-9));
      expect(c.isEmpty, false);
    });

    test('空コレクション', () {
      const c = BadgeCollection([]);
      expect(c.isEmpty, true);
      expect(c.total, 0);
      expect(c.earnedCount, 0);
      expect(c.completionRatio, 0.0);
      expect(c.summaryLabel, '獲得 0 / 0');
    });

    test('earned / locked は宣言順を維持', () {
      final c = BadgeCollection([
        _bp('a', 1, 1, true),
        _bp('b', 2, 5, false),
        _bp('c', 5, 5, true),
      ]);
      expect(c.earned.map((b) => b.definition.id), ['a', 'c']);
      expect(c.locked.map((b) => b.definition.id), ['b']);
    });

    test('badgesOf はカテゴリで絞る', () {
      final c = BadgeCollection([
        BadgeProgress(
          definition: BadgeDefinition(
            id: 'books_1',
            name: 'x',
            description: 'x',
            icon: '📖',
            category: BadgeCategory.completedBooks,
            tier: 1,
            threshold: 1,
            metricKey: 'completedBooks',
          ),
          current: 1,
          isEarned: true,
        ),
        _bp('streak_3', 1, 3, false),
      ]);
      expect(
        c.badgesOf(BadgeCategory.completedBooks).map((b) => b.definition.id),
        ['books_1'],
      );
      expect(c.badgesOf(BadgeCategory.timeOfDay), isEmpty);
    });
  });

  group('badgeTierLabel', () {
    test('4段階のラベル', () {
      expect(badgeTierLabel(1), 'ブロンズ');
      expect(badgeTierLabel(2), 'シルバー');
      expect(badgeTierLabel(3), 'ゴールド');
      expect(badgeTierLabel(4), '伝説');
    });

    test('範囲外はブロンズ', () {
      expect(badgeTierLabel(0), 'ブロンズ');
      expect(badgeTierLabel(5), 'ブロンズ');
      expect(badgeTierLabel(-1), 'ブロンズ');
    });
  });
}
