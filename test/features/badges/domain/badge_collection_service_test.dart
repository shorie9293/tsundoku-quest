import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/badges/domain/badge_collection_service.dart';
import 'package:tsundoku_quest/features/badges/domain/badge_definition.dart';

ReadingSession _session(
  String startedAt, {
  int? durationMinutes,
  int? startPage,
  int? endPage,
}) {
  return ReadingSession(
    id: 's_${startedAt.hashCode}',
    userBookId: 'b1',
    startedAt: startedAt,
    startPage: startPage ?? 0,
    endPage: endPage,
    durationMinutes: durationMinutes,
    createdAt: startedAt,
  );
}

UserBook _book(BookStatus status) {
  return UserBook(
    id: 'ub_${status.value}',
    userId: 'u1',
    bookId: 'bk',
    status: status,
    medium: BookMedium.physical,
    createdAt: '2026-01-01T00:00:00',
  );
}

void main() {
  group('kBadgeDefinitions', () {
    test('24件・id重複なし', () {
      expect(BadgeCollectionService.kBadgeDefinitions.length, 24);
      final ids = BadgeCollectionService.kBadgeDefinitions
          .map((d) => d.id)
          .toList();
      expect(ids.toSet().length, 24);
    });

    test('全カテゴリを網羅する', () {
      final categories = BadgeCollectionService.kBadgeDefinitions
          .map((d) => d.category)
          .toSet();
      expect(categories, BadgeCategory.values.toSet());
    });

    test('カテゴリ毎の件数と metricKey', () {
      final defs = BadgeCollectionService.kBadgeDefinitions;
      expect(
        defs.where((d) => d.metricKey == 'completedBooks').length,
        5,
      );
      expect(defs.where((d) => d.metricKey == 'currentStreak').length, 4);
      expect(defs.where((d) => d.metricKey == 'readingMinutes').length, 5);
      expect(defs.where((d) => d.metricKey == 'pagesTotal').length, 4);
      expect(
        defs.where((d) => d.metricKey == 'earlyMorningSessions').length,
        3,
      );
      expect(defs.where((d) => d.metricKey == 'nightSessions').length, 3);
    });
  });

  group('metrics', () {
    test('7キーが必ず存在する', () {
      final m = BadgeCollectionService.metrics(
        sessions: const [],
        userBooks: const [],
        now: DateTime(2026, 10, 13, 12),
      );
      expect(
        m.keys.toSet(),
        {
          'completedBooks',
          'readingMinutes',
          'pagesTotal',
          'currentStreak',
          'longestStreak',
          'earlyMorningSessions',
          'nightSessions',
        },
      );
    });

    test('completedBooks は completed 状態のみ', () {
      final m = BadgeCollectionService.metrics(
        sessions: const [],
        userBooks: [
          _book(BookStatus.completed),
          _book(BookStatus.completed),
          _book(BookStatus.reading),
          _book(BookStatus.tsundoku),
        ],
        now: DateTime(2026, 10, 13, 12),
      );
      expect(m['completedBooks'], 2);
    });

    test('readingMinutes は durationMinutes>0 のみ加算', () {
      final m = BadgeCollectionService.metrics(
        sessions: [
          _session('2026-10-13T10:00:00', durationMinutes: 30),
          _session('2026-10-13T11:00:00', durationMinutes: 0),
          _session('2026-10-13T12:00:00', durationMinutes: -5),
          _session('2026-10-13T13:00:00'),
        ],
        userBooks: const [],
        now: DateTime(2026, 10, 13, 20),
      );
      expect(m['readingMinutes'], 30);
    });

    test('pagesTotal は endPage>startPage のみ加算', () {
      final m = BadgeCollectionService.metrics(
        sessions: [
          _session('2026-10-13T10:00:00', startPage: 10, endPage: 60), // +50
          _session('2026-10-13T11:00:00', startPage: 5, endPage: 5), // 0
          _session('2026-10-13T12:00:00', startPage: 50, endPage: 30), // 逆行
          _session('2026-10-13T13:00:00', startPage: 1), // endPageなし
        ],
        userBooks: const [],
        now: DateTime(2026, 10, 13, 20),
      );
      expect(m['pagesTotal'], 50);
    });

    test('currentStreak: 今日を含む3日連続 → 3', () {
      final m = BadgeCollectionService.metrics(
        sessions: [
          _session('2026-10-13T10:00:00'), // 今日
          _session('2026-10-12T22:30:00'),
          _session('2026-10-11T07:00:00'),
        ],
        userBooks: const [],
        now: DateTime(2026, 10, 13, 21),
      );
      expect(m['currentStreak'], 3);
      expect(m['longestStreak'], 3);
    });

    test('currentStreak: 最新が昨日のみ → 1（now前日許容）', () {
      final m = BadgeCollectionService.metrics(
        sessions: [_session('2026-10-12T23:00:00')],
        userBooks: const [],
        now: DateTime(2026, 10, 13, 9),
      );
      expect(m['currentStreak'], 1);
    });

    test('currentStreak: 最新が2日前 → 0', () {
      final m = BadgeCollectionService.metrics(
        sessions: [
          _session('2026-10-10T10:00:00'),
          _session('2026-10-11T10:00:00'),
        ],
        userBooks: const [],
        now: DateTime(2026, 10, 13, 9),
      );
      expect(m['currentStreak'], 0);
    });

    test('longestStreak は途切れていても最大連続を返す', () {
      final m = BadgeCollectionService.metrics(
        sessions: [
          _session('2026-10-01T10:00:00'),
          _session('2026-10-02T10:00:00'),
          _session('2026-10-03T10:00:00'),
          _session('2026-10-10T10:00:00'),
        ],
        userBooks: const [],
        now: DateTime(2026, 10, 20, 9),
      );
      expect(m['longestStreak'], 3);
      expect(m['currentStreak'], 0);
    });

    test('早朝(5-7時)と夜(22時以降/4時以前)の分類', () {
      final m = BadgeCollectionService.metrics(
        sessions: [
          _session('2026-10-13T05:30:00'),
          _session('2026-10-13T06:00:00'),
          _session('2026-10-13T07:59:00'),
          _session('2026-10-13T22:00:00'),
          _session('2026-10-13T23:59:00'),
          _session('2026-10-13T00:30:00'),
          _session('2026-10-13T04:59:00'),
          _session('2026-10-13T08:00:00'), // どちらでもない
          _session('2026-10-13T12:00:00'), // どちらでもない
          _session('2026-10-13T21:59:00'), // どちらでもない
        ],
        userBooks: const [],
        now: DateTime(2026, 10, 13, 21),
      );
      expect(m['earlyMorningSessions'], 3);
      expect(m['nightSessions'], 4);
    });

    test('不正 startedAt は黙って除外する', () {
      final m = BadgeCollectionService.metrics(
        sessions: [
          _session(''),
          _session('not-a-date'),
          _session('invalid/2026-13-45T99:99:99'),
          _session('2026-10-13T06:00:00'),
        ],
        userBooks: const [],
        now: DateTime(2026, 10, 13, 9),
      );
      expect(m['earlyMorningSessions'], 1);
      expect(m['nightSessions'], 0);
      expect(m['currentStreak'], 1);
    });
  });

  group('build', () {
    test('閾値到達バッジのみ isEarned=true・宣言順を厳守', () {
      final collection = BadgeCollectionService.build(
        sessions: [
          _session('2026-10-13T10:00:00', durationMinutes: 30),
          _session('2026-10-13T06:00:00', startPage: 10, endPage: 110),
        ],
        userBooks: [_book(BookStatus.completed)],
        now: DateTime(2026, 10, 13, 21),
      );

      expect(collection.total, 24);
      // 宣言順: books_1 が先頭
      expect(collection.badges.first.definition.id, 'books_1');

      final earned = collection.earned.map((b) => b.definition.id).toSet();
      // books_1(1冊), minutes_60(30分→未達), pages_100(100ページ→丁度達成)
      expect(earned, contains('books_1'));
      expect(earned, contains('pages_100'));
      expect(earned, contains('morning_1'));
      expect(earned, isNot(contains('books_5')));
      expect(earned, isNot(contains('minutes_60')));

      final books1 =
          collection.badges.firstWhere((b) => b.definition.id == 'books_1');
      expect(books1.isEarned, true);
      expect(books1.earnedAt, isNull); // build では必ず null
      expect(books1.current, 1);
      expect(books1.percent, 100);
    });

    test('メトリクス欠落時は current=0', () {
      final collection = BadgeCollectionService.build(
        sessions: const [],
        userBooks: const [],
        now: DateTime(2026, 10, 13, 12),
      );
      for (final b in collection.badges) {
        expect(b.isEarned, false, reason: b.definition.id);
        expect(b.current, 0);
      }
    });
  });

  group('attachEarnedAt', () {
    test('獲得済みに earnedAt を付け、未獲得・未知idを無視する', () {
      final collection = BadgeCollectionService.build(
        sessions: [
          _session('2026-10-13T10:00:00'),
        ],
        userBooks: [_book(BookStatus.completed)],
        now: DateTime(2026, 10, 13, 21),
      );

      final at1 = DateTime.utc(2026, 10, 10, 1, 2, 3);
      final attached = BadgeCollectionService.attachEarnedAt(collection, {
        'books_1': at1,
        'unknown_badge': DateTime.utc(2026, 10, 11),
      });

      final books1 =
          attached.badges.firstWhere((b) => b.definition.id == 'books_1');
      expect(books1.earnedAt, at1);

      // 未獲得バッジは置き換え対象外
      final locked = attached.locked;
      expect(locked, isNotEmpty);
      for (final b in locked) {
        expect(b.earnedAt, isNull, reason: b.definition.id);
      }

      // 元のコレクションは不変（純粋関数）
      final before =
          collection.badges.firstWhere((b) => b.definition.id == 'books_1');
      expect(before.earnedAt, isNull);
    });
  });
}
