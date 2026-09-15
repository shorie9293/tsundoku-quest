import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/features/share_card/domain/share_card_data.dart';

void main() {
  final base = ShareCardData(
    title: '積読のすすめ',
    authors: const ['山田太郎'],
    completedAt: DateTime.utc(2026, 9, 15),
  );

  group('ShareCardData', () {
    test('既定値は pages 0 / rating null / shelves 空 / readingMinutes 0', () {
      expect(base.pages, 0);
      expect(base.rating, isNull);
      expect(base.shelves, isEmpty);
      expect(base.readingMinutes, 0);
    });

    test('authorLabel は著者を読点で連結する', () {
      final data = ShareCardData(
        title: 't',
        authors: const ['山田太郎', '鈴木花子'],
        completedAt: DateTime.utc(2026, 1, 1),
      );
      expect(data.authorLabel, '山田太郎、鈴木花子');
    });

    test('authors が空なら著者不明を返す', () {
      final data = ShareCardData(
        title: 't',
        completedAt: DateTime.utc(2026, 1, 1),
      );
      expect(data.authorLabel, '著者不明');
    });

    test('dateLabel は年月日で整形する', () {
      expect(base.dateLabel, '2026年9月15日');
    });

    test('dateLabel は月初・年末もゼロ埋めしない', () {
      expect(
        ShareCardData(title: 't', completedAt: DateTime.utc(2026, 12, 1))
            .dateLabel,
        '2026年12月1日',
      );
    });

    test('pagesLabel はページ数不明を返す（0ページ）', () {
      expect(base.pagesLabel, 'ページ数不明');
    });

    test('pagesLabel はページ数を返す', () {
      final data = ShareCardData(
        title: 't',
        completedAt: DateTime.utc(2026, 1, 1),
        pages: 320,
      );
      expect(data.pagesLabel, '320ページ');
    });

    test('hasRating は 1..5 のみ true', () {
      ShareCardData withRating(int? r) => ShareCardData(
            title: 't',
            completedAt: DateTime.utc(2026, 1, 1),
            rating: r,
          );
      expect(withRating(null).hasRating, isFalse);
      expect(withRating(0).hasRating, isFalse);
      expect(withRating(6).hasRating, isFalse);
      expect(withRating(-1).hasRating, isFalse);
      expect(withRating(1).hasRating, isTrue);
      expect(withRating(5).hasRating, isTrue);
    });
  });
}
