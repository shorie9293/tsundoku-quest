import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/reading_session.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/history/data/reading_forecast_service.dart';

UserBook ub({
  String id = 'ub1',
  BookStatus status = BookStatus.reading,
  int currentPage = 100,
  int? startedAtDaysAgo = 10,
  Book? book,
}) {
  final now = DateTime(2026, 9, 17, 12);
  return UserBook(
    id: id,
    userId: 'u1',
    bookId: 'b1',
    book: book,
    status: status,
    medium: BookMedium.physical,
    currentPage: currentPage,
    totalReadingMinutes: 300,
    startedAt: startedAtDaysAgo == null
        ? null
        : now.subtract(Duration(days: startedAtDaysAgo)).toIso8601String(),
    createdAt: now.toIso8601String(),
  );
}

Book book({int? pageCount, String title = 'テスト本'}) {
  return Book(
    id: 'b1',
    title: title,
    pageCount: pageCount,
    source: BookSource.manual,
    createdAt: '2026-09-01T00:00:00Z',
  );
}

ReadingSession session({
  required String id,
  required DateTime startedAt,
  int startPage = 0,
  int? endPage,
}) {
  return ReadingSession(
    id: id,
    userBookId: 'ub1',
    startedAt: startedAt.toIso8601String(),
    startPage: startPage,
    endPage: endPage,
    createdAt: startedAt.toIso8601String(),
  );
}

void main() {
  final now = DateTime(2026, 9, 17, 12);

  group('ReadingForecastService.paceFrom', () {
    test('セッションなしは null（ペース不明）', () {
      final pace = ReadingForecastService.paceFrom(sessions: const [], now: now);
      expect(pace, isNull);
    });

    test('単日1セッション: 30ページ読み = 30ページ/日', () {
      final sessions = [
        session(
          id: 's1',
          startedAt: DateTime(2026, 9, 16, 10),
          startPage: 70,
          endPage: 100,
        ),
      ];
      final pace = ReadingForecastService.paceFrom(
        sessions: sessions,
        now: now,
      );
      expect(pace, 30.0);
    });

    test('複数日は活動日数で割る（連続2日で60ページ = 30/日）', () {
      final sessions = [
        session(
          id: 's1',
          startedAt: DateTime(2026, 9, 15, 10),
          startPage: 40,
          endPage: 70,
        ),
        session(
          id: 's2',
          startedAt: DateTime(2026, 9, 16, 10),
          startPage: 70,
          endPage: 100,
        ),
      ];
      final pace = ReadingForecastService.paceFrom(
        sessions: sessions,
        now: now,
      );
      expect(pace, 30.0);
    });

    test('endPage 未記入セッションはページ計上しないが日は数える', () {
      final sessions = [
        session(
          id: 's1',
          startedAt: DateTime(2026, 9, 15, 10),
          startPage: 40,
        ),
        session(
          id: 's2',
          startedAt: DateTime(2026, 9, 16, 10),
          startPage: 70,
          endPage: 100,
        ),
      ];
      final pace = ReadingForecastService.paceFrom(
        sessions: sessions,
        now: now,
      );
      expect(pace, 15.0); // 30ページ / 2活動日（未記入日も分母に数える＝保守的）
    });

    test('同一天の複数セッションは合算し活動日は1日', () {
      final sessions = [
        session(
          id: 's1',
          startedAt: DateTime(2026, 9, 16, 8),
          startPage: 70,
          endPage: 85,
        ),
        session(
          id: 's2',
          startedAt: DateTime(2026, 9, 16, 20),
          startPage: 85,
          endPage: 100,
        ),
      ];
      final pace = ReadingForecastService.paceFrom(
        sessions: sessions,
        now: now,
      );
      expect(pace, 30.0);
    });

    test('総ページ 0 以下は null', () {
      final sessions = [
        session(
          id: 's1',
          startedAt: DateTime(2026, 9, 16, 10),
          startPage: 100,
          endPage: 100,
        ),
      ];
      final pace = ReadingForecastService.paceFrom(
        sessions: sessions,
        now: now,
      );
      expect(pace, isNull);
    });

    test('他の本のセッション（userBookId不一致）は無視', () {
      final s = session(
        id: 's1',
        startedAt: DateTime(2026, 9, 16, 10),
        startPage: 0,
        endPage: 30,
      );
      final other = ReadingSession(
        id: 's2',
        userBookId: 'other',
        startedAt: DateTime(2026, 9, 16, 10).toIso8601String(),
        startPage: 0,
        endPage: 50,
        createdAt: DateTime(2026, 9, 16, 10).toIso8601String(),
      );
      final pace = ReadingForecastService.paceFrom(
        sessions: [s, other],
        now: now,
        userBookId: 'ub1',
      );
      expect(pace, 30.0);
    });
  });

  group('ReadingForecastService.forecast', () {
    test('基本: 100/300ページ・30ページ/日 → 残200・7日後読了', () {
      final f = ReadingForecastService.forecast(
        userBook: ub(book: book(pageCount: 300)),
        sessions: [
          session(
            id: 's1',
            startedAt: DateTime(2026, 9, 16, 10),
            startPage: 70,
            endPage: 100,
          ),
        ],
        now: now,
      );
      expect(f, isNotNull);
      expect(f!.currentPage, 100);
      expect(f.totalPages, 300);
      expect(f.pagesPerDay, 30.0);
      expect(f.remainingPages, 200);
      expect(f.daysRemaining, 7); // ceil(200/30)
      expect(f.forecastDate, DateTime(2026, 9, 24));
      expect(f.isUnknown, isFalse);
      expect(f.isDone, isFalse);
    });

    test(' currentPage >= totalPages なら即読了扱い', () {
      final f = ReadingForecastService.forecast(
        userBook: ub(currentPage: 300, book: book(pageCount: 300)),
        sessions: [
          session(
            id: 's1',
            startedAt: DateTime(2026, 9, 16, 10),
            startPage: 70,
            endPage: 100,
          ),
        ],
        now: now,
      );
      expect(f, isNotNull);
      expect(f!.remainingPages, 0);
      expect(f.daysRemaining, 0);
      expect(f.isDone, isTrue);
      expect(f.isUnknown, isFalse);
    });

    test('セッションなし（ペース不明）→ isUnknown・forecastDate null', () {
      final f = ReadingForecastService.forecast(
        userBook: ub(book: book(pageCount: 300)),
        sessions: const [],
        now: now,
      );
      expect(f, isNotNull);
      expect(f!.isUnknown, isTrue);
      expect(f.forecastDate, isNull);
      expect(f.daysRemaining, isNull);
      expect(f.pagesPerDay, isNull);
    });

    test('pageCount 不明 → totalPages null・残ページ不明だがペースは出す', () {
      final f = ReadingForecastService.forecast(
        userBook: ub(book: book(pageCount: null)),
        sessions: [
          session(
            id: 's1',
            startedAt: DateTime(2026, 9, 16, 10),
            startPage: 70,
            endPage: 100,
          ),
        ],
        now: now,
      );
      expect(f, isNotNull);
      expect(f!.totalPages, isNull);
      expect(f.remainingPages, isNull);
      expect(f.forecastDate, isNull);
      expect(f.isUnknown, isTrue);
      expect(f.pagesPerDay, 30.0);
    });

    test('tsundoku（未開始）は null を返す', () {
      final f = ReadingForecastService.forecast(
        userBook: ub(status: BookStatus.tsundoku, startedAtDaysAgo: null),
        sessions: const [],
        now: now,
      );
      expect(f, isNull);
    });

    test('completed は null を返す', () {
      final f = ReadingForecastService.forecast(
        userBook: ub(status: BookStatus.completed),
        sessions: const [],
        now: now,
      );
      expect(f, isNull);
    });

    test('daysRemaining は切り上げ（残1ページ・ペース0.5）', () {
      final f = ReadingForecastService.forecast(
        userBook: ub(currentPage: 299, book: book(pageCount: 300)),
        sessions: [
          session(
            id: 's1',
            startedAt: DateTime(2026, 9, 16, 10),
            startPage: 0,
            endPage: 15,
          ),
          session(
            id: 's2',
            startedAt: DateTime(2026, 9, 17, 10),
            startPage: 15,
            endPage: 16,
          ),
        ],
        now: now,
      );
      // 残1ページ/ペース8ページ/日 → ceil = 1
      expect(f!.daysRemaining, 1);
      expect(f.forecastDate, DateTime(2026, 9, 18));
    });
  });

  group('ReadingForecastService.requiredDailyPages', () {
    test('残200ページ・10日後締切 = 20ページ/日', () {
      final req = ReadingForecastService.requiredDailyPages(
        currentPage: 100,
        totalPages: 300,
        targetDate: DateTime(2026, 9, 27),
        now: now,
      );
      expect(req, 20.0);
    });

    test('対象日当日は残日数1日扱い', () {
      final req = ReadingForecastService.requiredDailyPages(
        currentPage: 100,
        totalPages: 300,
        targetDate: DateTime(2026, 9, 17),
        now: now,
      );
      expect(req, 200.0);
    });

    test('過去の締切は null', () {
      final req = ReadingForecastService.requiredDailyPages(
        currentPage: 100,
        totalPages: 300,
        targetDate: DateTime(2026, 9, 16),
        now: now,
      );
      expect(req, isNull);
    });

    test('現在ページが総ページ以上なら 0', () {
      final req = ReadingForecastService.requiredDailyPages(
        currentPage: 300,
        totalPages: 300,
        targetDate: DateTime(2026, 9, 27),
        now: now,
      );
      expect(req, 0.0);
    });
  });

  group('ReadingForecastService.summaries', () {
    test('進行中の本から予測リストを構築（順序は保持・null除外）', () {
      final reading1 = ub(
        id: 'ub1',
        book: book(pageCount: 300),
        currentPage: 100,
      );
      final reading2 = ub(
        id: 'ub2',
        book: book(pageCount: 200, title: '二冊目'),
        currentPage: 50,
      );
      final done = ub(id: 'ub3', status: BookStatus.completed);
      final tsun = ub(id: 'ub4', status: BookStatus.tsundoku);
      final list = ReadingForecastService.summaries(
        books: [reading1, done, tsun, reading2],
        sessionsByBook: const {},
        now: now,
      );
      expect(list.length, 2);
      expect(list[0].userBookId, 'ub1');
      expect(list[1].userBookId, 'ub2');
      expect(list.every((f) => f.isUnknown), isTrue); // セッションなし
    });
  });
}
