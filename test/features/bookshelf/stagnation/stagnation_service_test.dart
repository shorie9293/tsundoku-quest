import 'package:flutter_test/flutter_test.dart';
import 'package:tsundoku_quest/domain/models/book.dart';
import 'package:tsundoku_quest/domain/models/user_book.dart';
import 'package:tsundoku_quest/features/bookshelf/domain/stagnation.dart';

UserBook _ub({
  required String id,
  required String createdAt,
  BookStatus status = BookStatus.tsundoku,
  int currentPage = 0,
  Book? book,
}) {
  return UserBook(
    id: id,
    userId: 'user-1',
    bookId: book?.id ?? 'book-$id',
    book: book,
    status: status,
    medium: BookMedium.physical,
    currentPage: currentPage,
    createdAt: createdAt,
  );
}

Book _book({
  required String id,
  required String title,
  List<String> authors = const [],
  int? pageCount,
}) {
  return Book(
    id: id,
    title: title,
    authors: authors,
    pageCount: pageCount,
    source: BookSource.manual,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  final now = DateTime.utc(2026, 10, 14);

  group('daysStalledFor', () {
    test('通常: 30日前に追加したら30日', () {
      final ub = _ub(id: 'a', createdAt: '2026-09-14T00:00:00Z');
      expect(StagnationService.daysStalledFor(ub, now: now), 30);
    });

    test('createdAtが未来なら0', () {
      final ub = _ub(id: 'a', createdAt: '2026-10-15T00:00:00Z');
      expect(StagnationService.daysStalledFor(ub, now: now), 0);
    });

    test('createdAtが解析不能なら0', () {
      final ub = _ub(id: 'a', createdAt: 'not-a-date');
      expect(StagnationService.daysStalledFor(ub, now: now), 0);
    });
  });

  group('detect', () {
    test('ちょうどminDaysは含み、-1日は含まない', () {
      final exactly = _ub(id: 'exact', createdAt: '2026-09-14T00:00:00Z');
      final less = _ub(id: 'less', createdAt: '2026-09-15T00:00:00Z');
      final result = StagnationService.detect(
        [exactly, less],
        now: now,
        minDays: 30,
      );
      expect(result.map((e) => e.userBook.id).toList(), ['exact']);
    });

    test('completedは除外、readingは含む', () {
      final done = _ub(
        id: 'done',
        createdAt: '2026-01-01T00:00:00Z',
        status: BookStatus.completed,
      );
      final reading = _ub(
        id: 'reading',
        createdAt: '2026-01-01T00:00:00Z',
        status: BookStatus.reading,
        currentPage: 10,
      );
      final result = StagnationService.detect([done, reading], now: now);
      expect(result.map((e) => e.userBook.id).toList(), ['reading']);
    });

    test('createdAt解析不能は除外', () {
      final bad = _ub(id: 'bad', createdAt: 'invalid');
      final good = _ub(id: 'good', createdAt: '2026-01-01T00:00:00Z');
      final result = StagnationService.detect([bad, good], now: now);
      expect(result.map((e) => e.userBook.id).toList(), ['good']);
    });

    test('入力順を保持する（ソートしない）', () {
      final b1 = _ub(id: 'z', createdAt: '2026-01-01T00:00:00Z');
      final b2 = _ub(id: 'a', createdAt: '2026-01-02T00:00:00Z');
      final result = StagnationService.detect([b1, b2], now: now);
      expect(result.map((e) => e.userBook.id).toList(), ['z', 'a']);
    });
  });

  group('reasonOf', () {
    test('tsundoku → neverStarted', () {
      final ub = _ub(id: 'a', createdAt: '2026-01-01T00:00:00Z');
      expect(StagnationService.reasonOf(ub), StagnationReason.neverStarted);
    });

    test('reading & currentPage==0 → noPageProgress', () {
      final ub = _ub(
        id: 'a',
        createdAt: '2026-01-01T00:00:00Z',
        status: BookStatus.reading,
        currentPage: 0,
      );
      expect(StagnationService.reasonOf(ub), StagnationReason.noPageProgress);
    });

    test('reading & currentPage>0 → longReading', () {
      final ub = _ub(
        id: 'a',
        createdAt: '2026-01-01T00:00:00Z',
        status: BookStatus.reading,
        currentPage: 5,
      );
      expect(StagnationService.reasonOf(ub), StagnationReason.longReading);
    });

    test('ラベル', () {
      expect(StagnationReason.neverStarted.label, '積読（未着手）');
      expect(StagnationReason.noPageProgress.label, '読書中だが進捗なし');
      expect(StagnationReason.longReading.label, '読書中（長期経過）');
    });
  });

  group('StagnantBook', () {
    UserBook mk(int days) => _ub(id: 'a', createdAt: '2026-01-01T00:00:00Z');

    test('daysStalled<0 で ArgumentError', () {
      expect(
        () => StagnantBook(
          userBook: mk(0),
          daysStalled: -1,
          reason: StagnationReason.neverStarted,
        ),
        throwsArgumentError,
      );
    });

    test('daysLabel', () {
      final e = StagnantBook(
        userBook: mk(0),
        daysStalled: 45,
        reason: StagnationReason.neverStarted,
      );
      expect(e.daysLabel, '45日放置');
    });

    test('title: bookがnullなら（無題）', () {
      final e = StagnantBook(
        userBook: mk(0),
        daysStalled: 0,
        reason: StagnationReason.neverStarted,
      );
      expect(e.title, '（無題）');
      expect(e.authors, isEmpty);
    });

    test('progressLabel: pageCount不明ならnull', () {
      final noPage = _ub(
        id: 'a',
        createdAt: '2026-01-01T00:00:00Z',
        book: _book(id: 'b1', title: 'T'),
      );
      final zeroPage = _ub(
        id: 'b',
        createdAt: '2026-01-01T00:00:00Z',
        book: _book(id: 'b2', title: 'T', pageCount: 0),
      );
      final withPage = _ub(
        id: 'c',
        createdAt: '2026-01-01T00:00:00Z',
        currentPage: 120,
        book: _book(id: 'b3', title: 'T', pageCount: 300),
      );
      final overflow = _ub(
        id: 'd',
        createdAt: '2026-01-01T00:00:00Z',
        currentPage: 999,
        book: _book(id: 'b4', title: 'T', pageCount: 100),
      );
      final eNo = StagnantBook(
        userBook: noPage,
        daysStalled: 0,
        reason: StagnationReason.neverStarted,
      );
      final eZero = StagnantBook(
        userBook: zeroPage,
        daysStalled: 0,
        reason: StagnationReason.neverStarted,
      );
      final eWith = StagnantBook(
        userBook: withPage,
        daysStalled: 0,
        reason: StagnationReason.longReading,
      );
      final eOver = StagnantBook(
        userBook: overflow,
        daysStalled: 0,
        reason: StagnationReason.longReading,
      );
      expect(eNo.progressLabel(), isNull);
      expect(eZero.progressLabel(), isNull);
      expect(eWith.progressLabel(), '120 / 300 ページ');
      expect(eOver.progressLabel(), '100 / 100 ページ');
    });

    test('authors: book結合時は著者一覧', () {
      final ub = _ub(
        id: 'a',
        createdAt: '2026-01-01T00:00:00Z',
        book: _book(id: 'b', title: 'T', authors: ['夏目 漱石']),
      );
      final e = StagnantBook(
        userBook: ub,
        daysStalled: 0,
        reason: StagnationReason.neverStarted,
      );
      expect(e.authors, ['夏目 漱石']);
    });
  });

  group('sortByDays', () {
    StagnantBook entry(String id, int days, {String? title}) {
      final ub = _ub(
        id: id,
        createdAt: '2026-01-01T00:00:00Z',
        book: _book(id: 'bk-$id', title: title ?? 'T$id'),
      );
      return StagnantBook(
        userBook: ub,
        daysStalled: days,
        reason: StagnationReason.neverStarted,
      );
    }

    test('daysStalled降順', () {
      final result = StagnationService.sortByDays([
        entry('a', 10),
        entry('b', 90),
        entry('c', 40),
      ]);
      expect(result.map((e) => e.userBook.id).toList(), ['b', 'c', 'a']);
    });

    test('同日数はtitle昇順→id昇順', () {
      final result = StagnationService.sortByDays([
        entry('x2', 30, title: 'B'),
        entry('x1', 30, title: 'C'),
        entry('x0', 30, title: 'A'),
        entry('x3', 30, title: 'A'), // title同値 → id昇順で先頭側へ
      ]);
      expect(result.map((e) => e.userBook.id).toList(), [
        'x0',
        'x3',
        'x2',
        'x1',
      ]);
    });

    test('非破壊（元リストは変更されない）', () {
      final original = [entry('a', 10), entry('b', 90)];
      final before = List.of(original);
      StagnationService.sortByDays(original);
      expect(original.map((e) => e.userBook.id).toList(),
          before.map((e) => e.userBook.id).toList());
    });
  });

  group('filterByReason', () {
    test('nullは全件、指定理由のみ絞り込み', () {
      StagnantBook e(String id, StagnationReason r) {
        final ub = _ub(id: id, createdAt: '2026-01-01T00:00:00Z');
        return StagnantBook(userBook: ub, daysStalled: 30, reason: r);
      }

      final entries = [
        e('a', StagnationReason.neverStarted),
        e('b', StagnationReason.noPageProgress),
        e('c', StagnationReason.neverStarted),
      ];
      expect(StagnationService.filterByReason(entries, null).length, 3);
      expect(
        StagnationService.filterByReason(entries, StagnationReason.neverStarted)
            .map((e) => e.userBook.id),
        ['a', 'c'],
      );
    });
  });

  group('searchByText', () {
    StagnantBook e(String id, String title, List<String> authors) {
      final ub = _ub(
        id: id,
        createdAt: '2026-01-01T00:00:00Z',
        book: _book(id: 'bk-$id', title: title, authors: authors),
      );
      return StagnantBook(
        userBook: ub,
        daysStalled: 30,
        reason: StagnationReason.neverStarted,
      );
    }

    final entries = [
      e('1', 'ｄｅｖｅｌｏｐｍｅｎｔ 入門', []), // 全角英字
      e('2', 'Python実践', ['ＡＢＣ 太郎']), // 著者が全角
      e('3', '別の本', ['山田 花子']),
    ];

    test('空クエリは全件', () {
      expect(StagnationService.searchByText(entries, ''), entries);
      expect(StagnationService.searchByText(entries, '   '), entries);
    });

    test('大文字小文字を無視した部分一致', () {
      final r = StagnationService.searchByText(entries, 'PYTHON');
      expect(r.map((e) => e.userBook.id), ['2']);
    });

    test('全角英字のクエリは半角に正規化して一致', () {
      final r = StagnationService.searchByText(entries, 'ｄｅｖｅｌｏｐｍｅｎｔ');
      expect(r.map((e) => e.userBook.id), ['1']);
    });

    test('全角スペースを含むクエリも正規化', () {
      final r = StagnationService.searchByText(entries, 'ＡＢＣ　太郎');
      expect(r.map((e) => e.userBook.id), ['2']);
    });
  });

  group('countsByReason', () {
    test('理由別に件数を数える', () {
      StagnantBook e(String id, StagnationReason r) {
        final ub = _ub(id: id, createdAt: '2026-01-01T00:00:00Z');
        return StagnantBook(userBook: ub, daysStalled: 30, reason: r);
      }

      final entries = [
        e('a', StagnationReason.neverStarted),
        e('b', StagnationReason.neverStarted),
        e('c', StagnationReason.longReading),
      ];
      final counts = StagnationService.countsByReason(entries);
      expect(counts[StagnationReason.neverStarted], 2);
      expect(counts[StagnationReason.longReading], 1);
      expect(counts[StagnationReason.noPageProgress], isNull);
    });

    test('空リストは空Map', () {
      expect(StagnationService.countsByReason(const []), isEmpty);
    });
  });
}
